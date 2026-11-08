#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOReturn.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDElement.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static void set_number(CFMutableDictionaryRef d, CFStringRef key, int n) {
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &n);
    CFDictionarySetValue(d, key, value);
    CFRelease(value);
}
static int matches_usage(IOHIDDeviceRef d) {
    if (IOHIDDeviceConformsTo(d, 0xFF00, 0x000F)) return 1;
    CFTypeRef page = IOHIDDeviceGetProperty(d, CFSTR(kIOHIDPrimaryUsagePageKey));
    CFTypeRef usage = IOHIDDeviceGetProperty(d, CFSTR(kIOHIDPrimaryUsageKey));
    int p=0, u=0;
    if (!page || !usage || CFGetTypeID(page)!=CFNumberGetTypeID() ||
        CFGetTypeID(usage)!=CFNumberGetTypeID()) return 0;
    CFNumberGetValue((CFNumberRef)page, kCFNumberIntType, &p);
    CFNumberGetValue((CFNumberRef)usage, kCFNumberIntType, &u);
    return p==0xFF00 && u==0x000F;
}

/* Descriptor seen on this A2141:
 * ID 1: 32-bit brightness (100..14660), 32-bit auxiliary (0..65535)
 * ID 3:  8-bit power (0..1),        32-bit auxiliary (0..65535)
 * IMPORTANT: report 1 is 9 bytes; report 3 is 6 bytes, including report ID.
 */
static int inspect_protocol(IOHIDDeviceRef d, int *minBrightness, int *maxBrightness) {
    int b1=0, b2=0, p1=0, p2=0, unexpected=0;
    CFArrayRef arr=IOHIDDeviceCopyMatchingElements(d, NULL, 0);
    if (!arr) { puts("Geen HID-elementen beschikbaar."); return 0; }
    printf("HID feature-velden:\n");
    for (CFIndex i=0;i<CFArrayGetCount(arr);++i) {
        IOHIDElementRef e=(IOHIDElementRef)CFArrayGetValueAtIndex(arr,i);
        if (IOHIDElementGetType(e)!=kIOHIDElementTypeFeature) continue;
        CFIndex id=IOHIDElementGetReportID(e);
        if (id!=1 && id!=3) continue;
        CFIndex bits=IOHIDElementGetReportSize(e);
        CFIndex count=IOHIDElementGetReportCount(e);
        CFIndex lo=IOHIDElementGetLogicalMin(e), hi=IOHIDElementGetLogicalMax(e);
        printf("  ID %ld: %ld bits x %ld, bereik %ld..%ld\n",
               (long)id,(long)bits,(long)count,(long)lo,(long)hi);
        if (count!=1) { unexpected++; continue; }
        if (id==1 && bits==32 && lo>=1 && lo<=100 && hi>=1000 && hi<65535) {
            b1++; *minBrightness=(int)lo; *maxBrightness=(int)hi;
        } else if (id==1 && bits==32 && lo==0 && hi==65535) b2++;
        else if (id==3 && bits==8 && lo==0 && hi==1) p1++;
        else if (id==3 && bits==32 && lo==0 && hi==65535) p2++;
        else unexpected++;
    }
    CFRelease(arr);
    int ok=(b1==1 && b2==1 && p1==1 && p2==1 && unexpected==0);
    printf("Protocolcontrole: %s (brightness %d..%d)\n",
           ok?"OK":"NIET bevestigd", *minBrightness, *maxBrightness);
    return ok;
}

static void set32le(uint8_t *b, uint32_t value) {
    b[0]=(uint8_t)value;
    b[1]=(uint8_t)(value>>8);
    b[2]=(uint8_t)(value>>16);
    b[3]=(uint8_t)(value>>24);
}
static int send_feature(IOHIDDeviceRef d, const uint8_t *report, size_t n) {
    printf("SetReport ID %u (%zu bytes):",(unsigned)report[0],n);
    for(size_t i=0;i<n;i++) printf(" %02x",report[i]);
    putchar('\n');
    IOReturn rc=IOHIDDeviceSetReport(d,kIOHIDReportTypeFeature,report[0],report,(CFIndex)n);
    printf("Resultaat: 0x%08x (%s)\n",(unsigned)rc,
           rc==kIOReturnSuccess?"geaccepteerd door macOS":"fout");
    return rc==kIOReturnSuccess;
}
int main(int argc, char **argv) {
    const char *mode=argc>=2?argv[1]:"probe";
    const char *arg=argc>=3?argv[2]:"0.5";
    char *end=NULL;
    double level=strtod(arg,&end);
    if (!strcmp(mode,"on") && (!end || end==arg || *end!='\0' || level<0.1 || level>1.0)) {
        fputs("Fout: voor on een waarde van 0.1 t/m 1.0 gebruiken.\n",stderr);
        return 2;
    }
    printf("MacBookPro16,1 - T2 HID v2 - modus: %s\n",mode);
    IOHIDManagerRef manager=IOHIDManagerCreate(kCFAllocatorDefault,0);
    if(!manager) return 3;
    CFMutableDictionaryRef match=CFDictionaryCreateMutable(kCFAllocatorDefault,0,
                   &kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    set_number(match,CFSTR(kIOHIDVendorIDKey),0x05ac);
    set_number(match,CFSTR(kIOHIDProductIDKey),0x8102);
    IOHIDManagerSetDeviceMatching(manager,match);
    CFRelease(match);
    IOReturn rc=IOHIDManagerOpen(manager,0);
    printf("IOHIDManagerOpen: 0x%08x\n",(unsigned)rc);
    if(rc!=kIOReturnSuccess) { CFRelease(manager); return 4; }
    CFSetRef set=IOHIDManagerCopyDevices(manager);
    CFIndex count=set?CFSetGetCount(set):0;
    IOHIDDeviceRef *devices=count?calloc((size_t)count,sizeof(*devices)):NULL;
    if(count) CFSetGetValues(set,(const void **)devices);
    IOHIDDeviceRef target=NULL;
    for(CFIndex i=0;i<count;i++) if(matches_usage(devices[i])) { target=devices[i]; break; }
    int result=0;
    if(!target) {
        puts("Geen HID-interface 05ac:8102 FF00/000F gevonden.");
        result=5;
    } else {
        puts("Doelinterface gevonden (05ac:8102 / FF00:000F).");
        int minB=0,maxB=0;
        int valid=inspect_protocol(target,&minB,&maxB);
        rc=IOHIDDeviceOpen(target,0); /* shared access, never seize */
        printf("IOHIDDeviceOpen: 0x%08x\n",(unsigned)rc);
        if(rc!=kIOReturnSuccess) result=6;
        else if(!strcmp(mode,"probe")) puts("Probe voltooid, geen schrijfacties.");
        else if(!valid) {
            puts("Rapportstructuur wijkt af: NIETS geschreven.");
            result=7;
        } else {
            /* Linux driver: auxiliary field = 0x015e when rate=1. */
            uint8_t power[6]={3,0,0x5e,0x01,0,0};
            if(!strcmp(mode,"off")) {
                if(!send_feature(target,power,sizeof(power))) result=8;
            } else {
                uint32_t brightness=(uint32_t)(maxB*level+0.5);
                if(brightness<(uint32_t)minB) brightness=(uint32_t)minB;
                uint8_t light[9]={1,0,0,0,0,0x5e,0x01,0,0};
                set32le(light+1,brightness);
                printf("Aanvraag: %.0f%% (ruwe helderheid %u, max %d)\n",
                       level*100.0,(unsigned)brightness,maxB);
                power[1]=1;
                if(!send_feature(target,power,sizeof(power))) result=8;
                else if(!send_feature(target,light,sizeof(light))) result=8;
            }
            if(result==0) puts("HID-verzoeken verzonden. Controleer visueel of de leds branden.");
        }
        if(rc==kIOReturnSuccess) IOHIDDeviceClose(target,0);
    }
    free(devices);
    if(set) CFRelease(set);
    IOHIDManagerClose(manager,0);
    CFRelease(manager);
    return result;
}
