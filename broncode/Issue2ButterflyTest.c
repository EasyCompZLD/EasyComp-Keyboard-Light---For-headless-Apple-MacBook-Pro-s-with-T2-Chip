/*
 * Isolated Issue #2 experiment, not part of the production HID helper.
 * BF configuration evidence: issuecomment-6810254280, MacBookPro15,4.
 * B0 output layout is the existing Butterfly protocol documented in hid-apple.c:
 * https://github.com/torvalds/linux/blob/master/drivers/hid/hid-apple.c
 * macOS output support remains unverified until this opt-in hardware test.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDElement.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <sys/sysctl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ISSUE2_CONFIRM "--confirm-probe=0:32:512"
static volatile sig_atomic_t issue2_stopping;
static void issue2_stop(int signal_number) { (void)signal_number; issue2_stopping=1; }
static uint16_t issue2_read16(const uint8_t *p) { return (uint16_t)(p[0]|((uint16_t)p[1]<<8)); }
static int issue2_number(IOHIDDeviceRef device, CFStringRef key) {
    int value=0;
    CFTypeRef property=IOHIDDeviceGetProperty(device,key);
    if(property && CFGetTypeID(property)==CFNumberGetTypeID())
        CFNumberGetValue((CFNumberRef)property,kCFNumberIntType,&value);
    return value;
}
static int issue2_set_number(CFMutableDictionaryRef dictionary, CFStringRef key, int value) {
    CFNumberRef number=CFNumberCreate(kCFAllocatorDefault,kCFNumberIntType,&value);
    if(!number)return 0;
    CFDictionarySetValue(dictionary,key,number);CFRelease(number);return 1;
}
static int issue2_candidate(IOHIDDeviceRef device) {
    if(issue2_number(device,CFSTR(kIOHIDVendorIDKey))!=0x05ac ||
       issue2_number(device,CFSTR(kIOHIDProductIDKey))!=0x027d ||
       issue2_number(device,CFSTR(kIOHIDPrimaryUsagePageKey))!=1 ||
       issue2_number(device,CFSTR(kIOHIDPrimaryUsageKey))!=6)return 0;
    CFArrayRef elements=IOHIDDeviceCopyMatchingElements(device,NULL,0);
    if(!elements)return 0;
    int signatures=0;
    for(CFIndex i=0;i<CFArrayGetCount(elements);i++) {
        IOHIDElementRef element=(IOHIDElementRef)CFArrayGetValueAtIndex(elements,i);
        IOHIDElementType type=IOHIDElementGetType(element);
        if((type==kIOHIDElementTypeInput_Misc || type==kIOHIDElementTypeInput_Button ||
            type==kIOHIDElementTypeInput_Axis) &&
           IOHIDElementGetUsagePage(element)==0xff00 && IOHIDElementGetUsage(element)==0xf &&
           IOHIDElementGetReportID(element)==0xbf && IOHIDElementGetReportSize(element)==120 &&
           IOHIDElementGetReportCount(element)==15 && IOHIDElementGetLogicalMin(element)==0 &&
           IOHIDElementGetLogicalMax(element)==255)signatures++;
    }
    CFRelease(elements);
    return signatures==1;
}
static int issue2_configuration(IOHIDDeviceRef device) {
    uint8_t bytes[64]={0xbf};CFIndex length=sizeof(bytes);
    IOReturn status=IOHIDDeviceGetReport(device,kIOHIDReportTypeFeature,0xbf,bytes,&length);
    printf("Feature GetReport 0xBF: status=0x%08x\n",(unsigned)status);
    if(status!=kIOReturnSuccess) {
        puts("Configuration read failed; no valid returned length or LED permission.");return 0;
    }
    printf("Returned length=%ld\n",(long)length);
    if(length!=8 || bytes[0]!=0xbf || bytes[1]!=1) {
        puts("Configuration structure does not match the confirmed report; no LED command permitted.");return 0;
    }
    unsigned off=issue2_read16(bytes+2), minimum=issue2_read16(bytes+4), maximum=issue2_read16(bytes+6);
    printf("Configuration: id=0xbf version=1 off=%u min=%u max=%u\n",off,minimum,maximum);
    if(off!=0 || minimum!=32 || maximum!=512) {
        puts("Configuration values differ from the confirmed hardware; no LED command permitted.");return 0;
    }
    return 1;
}
static int issue2_output(IOHIDDeviceRef device, uint16_t brightness) {
    /* Same six-byte B0/version-1/brightness/rate layout as the existing backend.
     * This test has no arbitrary brightness argument and permits only 0 or 32.
     */
    if(brightness!=0 && brightness!=32)return 0;
    uint8_t report[6]={0xb0,1,(uint8_t)brightness,(uint8_t)(brightness>>8),0,0};
    IOReturn status=IOHIDDeviceSetReport(device,kIOHIDReportTypeOutput,0xb0,report,sizeof(report));
    printf("Output SetReport 0xB0 value=%u: status=0x%08x\n",brightness,(unsigned)status);
    return status==kIOReturnSuccess;
}
static int issue2_lock(void) {
    char path[128];
    snprintf(path,sizeof(path),"/private/tmp/ecz-issue2-%u.lock",(unsigned)geteuid());
    int fd=open(path,O_CREAT|O_RDWR|O_NOFOLLOW|O_CLOEXEC,0600);
    if(fd<0)return -1;
    struct stat info;
    if(fstat(fd,&info)!=0 || !S_ISREG(info.st_mode) || info.st_uid!=geteuid() ||
       flock(fd,LOCK_EX|LOCK_NB)!=0) { close(fd);return -1; }
    return fd;
}
int main(int argc, char **argv) {
    const char *mode=argc>1?argv[1]:"probe";
    int probe=!strcmp(mode,"probe"), pulse=!strcmp(mode,"pulse"), off=!strcmp(mode,"off");
    if((!probe && !pulse && !off) || (probe && argc>2) ||
       (!probe && (argc!=3 || strcmp(argv[2],ISSUE2_CONFIRM)))) {
        puts("Usage: Issue2Helper probe | pulse --confirm-probe=0:32:512 | off --confirm-probe=0:32:512");
        puts("LED commands require an explicit reviewed-probe confirmation.");return 2;
    }
    if(geteuid()==0) { puts("Run as a regular user, not with administrator privileges.");return 3; }
    char model[128]={0};size_t model_length=sizeof(model)-1;
    if(sysctlbyname("hw.model",model,&model_length,NULL,0)!=0 || strcmp(model,"MacBookPro15,4")) {
        puts("This isolated test is restricted to MacBookPro15,4. No HID command sent.");return 3;
    }
    puts("Model: MacBookPro15,4. Target: 05ac:027d primary=0001/0006, input ff00/000f report=0xbf.");
    puts(probe?"READ-ONLY PROBE: no LED commands permitted.":"EXPLICIT EXPERIMENT: revalidating configuration before any LED command.");
    int lock_fd=issue2_lock();
    if(lock_fd<0) { puts("Another test is running or the per-user test lock is unavailable.");return 4; }
    issue2_stopping=0;
    struct sigaction action={0};action.sa_handler=issue2_stop;sigemptyset(&action.sa_mask);
    if(sigaction(SIGTERM,&action,NULL)!=0 || sigaction(SIGINT,&action,NULL)!=0) {
        puts("Could not install interruption cleanup. No HID command sent.");close(lock_fd);return 3;
    }
    IOHIDManagerRef manager=IOHIDManagerCreate(kCFAllocatorDefault,0);
    CFMutableDictionaryRef match=CFDictionaryCreateMutable(kCFAllocatorDefault,0,
        &kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
    CFSetRef devices=NULL;IOHIDDeviceRef *list=NULL, selected=NULL;
    int result=3, manager_open=0, device_open=0;
    if(!manager || !match) { puts("Could not allocate the restricted HID query.");goto cleanup; }
    if(!issue2_set_number(match,CFSTR(kIOHIDVendorIDKey),0x05ac) ||
       !issue2_set_number(match,CFSTR(kIOHIDProductIDKey),0x027d) ||
       !issue2_set_number(match,CFSTR(kIOHIDPrimaryUsagePageKey),1) ||
       !issue2_set_number(match,CFSTR(kIOHIDPrimaryUsageKey),6))goto cleanup;
    IOHIDManagerSetDeviceMatching(manager,match);
    IOReturn status=IOHIDManagerOpen(manager,0); // Never seize keyboard input.
    printf("HIDManagerOpen: status=0x%08x\n",(unsigned)status);
    if(status!=kIOReturnSuccess) { result=4;goto cleanup; }
    manager_open=1;
    devices=IOHIDManagerCopyDevices(manager);
    CFIndex count=devices?CFSetGetCount(devices):0;
    if(count<=0 || count>64) { puts("No unique supported keyboard interface found.");result=5;goto cleanup; }
    list=calloc((size_t)count,sizeof(*list));
    if(!list)goto cleanup;
    CFSetGetValues(devices,(const void **)list);
    int candidates=0;
    for(CFIndex i=0;i<count;i++)if(issue2_candidate(list[i])) { selected=list[i];candidates++; }
    printf("Strict matching candidates: %d\n",candidates);
    if(candidates!=1) { puts("Missing or ambiguous interface; refusing to open any candidate.");result=5;goto cleanup; }
    status=IOHIDDeviceOpen(selected,0);
    printf("HIDDeviceOpen: status=0x%08x\n",(unsigned)status);
    if(status!=kIOReturnSuccess) { result=6;goto cleanup; }
    device_open=1;
    if(!issue2_configuration(selected)) { result=7;goto cleanup; }
    if(probe) {
        puts("ECZ_ISSUE2_PROBE_OK");result=0;goto cleanup;
    }
    if(issue2_stopping) { puts("Interrupted before LED writes.");result=9;goto cleanup; }
    if(off) {
        result=issue2_output(selected,0)?0:8;
        if(result==0)puts("ECZ_ISSUE2_OFF_ACCEPTED");
        goto cleanup;
    }
    if(!issue2_output(selected,32)) {
        puts("Minimum-light request failed; no retry or alternative report attempted.");result=8;goto cleanup;
    }
    struct timespec delay={2,0};int timer_ok=1;
    /* Signals shorten the pulse; cleanup still attempts the validated off value. */
    while(!issue2_stopping) {
        if(nanosleep(&delay,&delay)==0)break;
        if(errno!=EINTR) { puts("Pulse timer failed; attempting off immediately.");timer_ok=0;break; }
    }
    if(!issue2_output(selected,0)) {
        puts("Off request failed. Physical light state is unconfirmed; report this result.");result=8;goto cleanup;
    }
    result=(issue2_stopping || !timer_ok)?9:0;
    puts(result==0?"ECZ_ISSUE2_PULSE_ACCEPTED":"Pulse ended early; the off request was accepted.");
    puts("Accepted HID requests do not prove visible LED operation. Record your observation.");
cleanup:
    if(device_open)IOHIDDeviceClose(selected,0);
    free(list);
    if(devices)CFRelease(devices);
    if(manager_open)IOHIDManagerClose(manager,0);
    if(match)CFRelease(match);
    if(manager)CFRelease(manager);
    close(lock_fd);
    return result;
}
