/*
 * EasyComp Keyboard Light v1.2.0-beta4
 * Backlight backend; no SMC or kernel modifications.
 *
 * IMPORTANT regression fix: do not open an IOHIDManager for all Apple HID
 * devices. On macOS Tahoe, that broad match can return 0xe00002c7
 * (kIOReturnUnsupported), even when the proven 05ac:8102 endpoint works.
 *
 * Magic backlight protocol (05ac:8102): confirmed on A2141, same descriptor
 * checks and exact feature report bytes as v1.1.0.
 * Butterfly protocol: experimental, discovered using separately restricted
 * Apple keyboard product IDs; no writes unless descriptor AND read-only
 * config report both match the expected protocol.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOReturn.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDElement.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define APPLE_VID 0x05ac
#define MAGIC_PID 0x8102

static void set_number(CFMutableDictionaryRef d, CFStringRef key, int n) {
    CFNumberRef v=CFNumberCreate(kCFAllocatorDefault,kCFNumberIntType,&n);
    if(v){CFDictionarySetValue(d,key,v);CFRelease(v);}
}
static int number(IOHIDDeviceRef d,CFStringRef key) {
    int n=0;
    CFTypeRef v=IOHIDDeviceGetProperty(d,key);
    if(v && CFGetTypeID(v)==CFNumberGetTypeID())
        CFNumberGetValue((CFNumberRef)v,kCFNumberIntType,&n);
    return n;
}
static int magic_usage(IOHIDDeviceRef d) {
    return IOHIDDeviceConformsTo(d,0xff00,0x000f) ||
       (number(d,CFSTR(kIOHIDPrimaryUsagePageKey))==0xff00 &&
        number(d,CFSTR(kIOHIDPrimaryUsageKey))==0x000f);
}
static int inspect_magic(IOHIDDeviceRef d,int *minB,int *maxB) {
    int b1=0,b2=0,p1=0,p2=0,bad=0;
    CFArrayRef arr=IOHIDDeviceCopyMatchingElements(d,NULL,0);
    if(!arr)return 0;
    for(CFIndex i=0;i<CFArrayGetCount(arr);i++) {
        IOHIDElementRef e=(IOHIDElementRef)CFArrayGetValueAtIndex(arr,i);
        if(IOHIDElementGetType(e)!=kIOHIDElementTypeFeature)continue;
        int id=(int)IOHIDElementGetReportID(e);
        if(id!=1 && id!=3)continue;
        int bits=(int)IOHIDElementGetReportSize(e);
        int count=(int)IOHIDElementGetReportCount(e);
        int lo=(int)IOHIDElementGetLogicalMin(e);
        int hi=(int)IOHIDElementGetLogicalMax(e);
        if(count!=1){bad++;continue;}
        if(id==1 && bits==32 && lo>=1 && lo<=100 && hi>=1000 && hi<65535)
            {b1++;*minB=lo;*maxB=hi;}
        else if(id==1 && bits==32 && lo==0 && hi==65535)b2++;
        else if(id==3 && bits==8 && lo==0 && hi==1)p1++;
        else if(id==3 && bits==32 && lo==0 && hi==65535)p2++;
        else bad++;
    }
    CFRelease(arr);
    return b1==1 && b2==1 && p1==1 && p2==1 && bad==0;
}
static int butterfly_usage(IOHIDDeviceRef d) {
    CFArrayRef a=IOHIDDeviceCopyMatchingElements(d,NULL,0);
    if(!a)return 0;
    int found=0;
    for(CFIndex i=0;i<CFArrayGetCount(a);i++){
        IOHIDElementRef e=(IOHIDElementRef)CFArrayGetValueAtIndex(a,i);
        IOHIDElementType t=IOHIDElementGetType(e);
        if((t==kIOHIDElementTypeInput_Misc || t==kIOHIDElementTypeInput_Button ||
            t==kIOHIDElementTypeInput_Axis) &&
            IOHIDElementGetUsagePage(e)==0xff00 && IOHIDElementGetUsage(e)==0xf)
            found=1;
    }
    CFRelease(a);
    return found;
}
static int butterfly_descriptor(IOHIDDeviceRef d) {
    CFArrayRef a=IOHIDDeviceCopyMatchingElements(d,NULL,0);
    if(!a)return 0;
    int output=0,feature=0;
    for(CFIndex i=0;i<CFArrayGetCount(a);i++){
        IOHIDElementRef e=(IOHIDElementRef)CFArrayGetValueAtIndex(a,i);
        int id=(int)IOHIDElementGetReportID(e);
        if(IOHIDElementGetType(e)==kIOHIDElementTypeOutput && id==0xb0)output=1;
        if(IOHIDElementGetType(e)==kIOHIDElementTypeFeature && id==0xbf)feature=1;
    }
    CFRelease(a);
    return output && feature;
}
static uint16_t read16(const uint8_t *p) {return (uint16_t)(p[0]|((uint16_t)p[1]<<8));}
static void put16(uint8_t *p,uint16_t n){p[0]=(uint8_t)n;p[1]=(uint8_t)(n>>8);}
static void put32(uint8_t *p,uint32_t n){for(int i=0;i<4;i++)p[i]=(uint8_t)(n>>(8*i));}
static int butterfly_config(IOHIDDeviceRef d,int *off,int *minB,int *maxB){
    uint8_t rep[64]={0};rep[0]=0xbf;CFIndex size=sizeof(rep);
    IOReturn r=IOHIDDeviceGetReport(d,kIOHIDReportTypeFeature,0xbf,rep,&size);
    if(r!=kIOReturnSuccess){printf("Butterfly read-only configuration error: 0x%08x\n",(unsigned)r);return 0;}
    if(size<8 || rep[0]!=0xbf || rep[1]!=1)return 0;
    *off=read16(rep+2);*minB=read16(rep+4);*maxB=read16(rep+6);
    return *minB>0 && *maxB>=*minB && *off<*minB;
}
static int set_report(IOHIDDeviceRef d,IOHIDReportType kind,const uint8_t *data,CFIndex n){
    IOReturn r=IOHIDDeviceSetReport(d,kind,data[0],data,n);
    printf("SetReport ID 0x%02x: 0x%08x\n",data[0],(unsigned)r);
    return r==kIOReturnSuccess;
}
static void describe(IOHIDDeviceRef d){
    printf("Candidate Apple 05ac:%04x primary %04x/%04x\n",
           (unsigned)number(d,CFSTR(kIOHIDProductIDKey)),
           (unsigned)number(d,CFSTR(kIOHIDPrimaryUsagePageKey)),
           (unsigned)number(d,CFSTR(kIOHIDPrimaryUsageKey)));
    CFArrayRef arr=IOHIDDeviceCopyMatchingElements(d,NULL,0);
    if(!arr)return;
    int shown=0;
    for(CFIndex i=0;i<CFArrayGetCount(arr) && shown<24;i++){
        IOHIDElementRef e=(IOHIDElementRef)CFArrayGetValueAtIndex(arr,i);
        IOHIDElementType t=IOHIDElementGetType(e);
        if(t!=kIOHIDElementTypeFeature && t!=kIOHIDElementTypeOutput)continue;
        printf("  %s report=0x%02x size=%ld bits count=%ld range=%ld..%ld\n",
             t==kIOHIDElementTypeFeature?"feature":"output",
             (unsigned)IOHIDElementGetReportID(e),
             (long)IOHIDElementGetReportSize(e),(long)IOHIDElementGetReportCount(e),
             (long)IOHIDElementGetLogicalMin(e),(long)IOHIDElementGetLogicalMax(e));
        shown++;
    }
    CFRelease(arr);
}

/* Each IOHIDManager only sees one (vendor, product) pair.
 * This is deliberate: broad Apple HID matching broke v1.2.0-beta2 on A2141.
 */
static int try_pid(int pid,const char *mode,double level,int *seen){
    IOHIDManagerRef manager=IOHIDManagerCreate(kCFAllocatorDefault,0);
    if(!manager)return -3;
    CFMutableDictionaryRef match=CFDictionaryCreateMutable(kCFAllocatorDefault,0,
             &kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    set_number(match,CFSTR(kIOHIDVendorIDKey),APPLE_VID);
    set_number(match,CFSTR(kIOHIDProductIDKey),pid);
    IOHIDManagerSetDeviceMatching(manager,match);
    CFRelease(match);
    IOReturn r=IOHIDManagerOpen(manager,0);
    if(r!=kIOReturnSuccess){
        printf("HIDManagerOpen (05ac:%04x): 0x%08x\n",pid,(unsigned)r);
        CFRelease(manager);
        return -4;
    }
    CFSetRef set=IOHIDManagerCopyDevices(manager);
    CFIndex n=set?CFSetGetCount(set):0;
    IOHIDDeviceRef *devs=n?calloc((size_t)n,sizeof(*devs)):NULL;
    if(n && !devs){if(set)CFRelease(set);IOHIDManagerClose(manager,0);CFRelease(manager);return -3;}
    if(n)CFSetGetValues(set,(const void **)devs);
    int rc=-5;
    for(CFIndex i=0;i<n;i++){
        IOHIDDeviceRef d=devs[i];
        int minB=0,maxB=0,off=0;
        int magic=(pid==MAGIC_PID && magic_usage(d) && inspect_magic(d,&minB,&maxB));
        int butterfly=(pid!=MAGIC_PID && butterfly_usage(d) && butterfly_descriptor(d));
        if(!magic && !butterfly){
            if(!strcmp(mode,"diagnose"))describe(d);
            continue;
        }
        printf("Candidate protocol: %s, PID 05ac:%04x\n",magic?"Magic (verified on A2141)":"Butterfly (experimental)",pid);
        *seen=1;
        r=IOHIDDeviceOpen(d,0);
        if(r!=kIOReturnSuccess){printf("HIDDeviceOpen: 0x%08x\n",(unsigned)r);rc=-6;continue;}
        if(butterfly && !butterfly_config(d,&off,&minB,&maxB)){
            puts("Butterfly report 0xBF did not validate; no write performed.");
            IOHIDDeviceClose(d,0);rc=-7;continue;
        }
        printf("Protocolcontrole: OK (brightness %d..%d)\n",minB,maxB);
        if(!strcmp(mode,"probe") || !strcmp(mode,"diagnose")){
            puts("Read-only protocol check completed. No LED commands sent.");
            rc=0;
        }else if(magic){
            uint8_t power[6]={3,0,0x5e,0x01,0,0};
            if(!strcmp(mode,"off"))rc=set_report(d,kIOHIDReportTypeFeature,power,6)?0:-8;
            else{
                uint8_t light[9]={1,0,0,0,0,0x5e,0x01,0,0};
                uint32_t val=(uint32_t)(maxB*level+0.5);
                if(val<(uint32_t)minB)val=(uint32_t)minB;
                put32(light+1,val);power[1]=1;
                rc=(set_report(d,kIOHIDReportTypeFeature,power,6) &&
                    set_report(d,kIOHIDReportTypeFeature,light,9))?0:-8;
            }
        }else{
            uint16_t val=(uint16_t)(!strcmp(mode,"off")?off:(int)(maxB*level+0.5));
            if(strcmp(mode,"off") && val<(uint16_t)minB)val=(uint16_t)minB;
            uint8_t output[6]={0xb0,1,0,0,0,0};put16(output+2,val);
            rc=set_report(d,kIOHIDReportTypeOutput,output,6)?0:-8;
        }
        IOHIDDeviceClose(d,0);
        if(rc==0)break;
    }
    free(devs);if(set)CFRelease(set);
    IOHIDManagerClose(manager,0);CFRelease(manager);
    return rc;
}
int main(int argc,char **argv){
    const char *mode=argc>1?argv[1]:"probe";
    if(strcmp(mode,"probe") && strcmp(mode,"diagnose") && strcmp(mode,"on") && strcmp(mode,"off")){
        fputs("Usage: helper probe | diagnose | on 0.1..1.0 | off\n",stderr);return 2;
    }
    double level=0.5;
    if(!strcmp(mode,"on")){
        const char *s=argc>2?argv[2]:"0.5";char *end=NULL;
        level=strtod(s,&end);
        if(!end || end==s || *end || level<0.1 || level>1.0){fputs("Invalid brightness.\n",stderr);return 2;}
    }
    /* Specific PIDs only: never open IOHIDManager against all Apple devices. */
    const int pids[]={MAGIC_PID,0x0340,0x027c,0x0276};
    int diagnostic=!strcmp(mode,"diagnose");
    int seen=0,found=-5,lastError=-5;
    for(size_t i=0;i<sizeof(pids)/sizeof(pids[0]);i++){
        /* For normal operation, do not probe further once validated. */
        int r=try_pid(pids[i],mode,level,&seen);
        if(r==0){found=0;if(!diagnostic)break;}
        else if(r!=-5)lastError=r;
    }
    if(found==0)return 0;
    puts("No supported backlight interface could be validated; no LED command sent.");
    if(lastError==-4)return 4;
    if(lastError==-6)return 6;
    if(lastError==-7)return 7;
    if(lastError==-8)return 8;
    return 5;
}
