/* Every HID API used by the real helper is replaced with a fixture here. */
#define IOHIDManagerCreate fixture_manager_create
#define IOHIDManagerSetDeviceMatching fixture_match
#define IOHIDManagerOpen fixture_manager_open
#define IOHIDManagerCopyDevices fixture_devices
#define IOHIDManagerClose fixture_manager_close
#define IOHIDDeviceGetProperty fixture_property
#define IOHIDDeviceCopyMatchingElements fixture_elements
#define IOHIDElementGetType fixture_type
#define IOHIDElementGetUsagePage fixture_page
#define IOHIDElementGetUsage fixture_usage
#define IOHIDElementGetReportID fixture_id
#define IOHIDElementGetReportSize fixture_bits
#define IOHIDElementGetReportCount fixture_count
#define IOHIDElementGetLogicalMin fixture_min
#define IOHIDElementGetLogicalMax fixture_max
#define IOHIDDeviceOpen fixture_device_open
#define IOHIDDeviceClose fixture_device_close
#define IOHIDDeviceGetReport fixture_get
#define IOHIDDeviceSetReport fixture_set
#define sysctlbyname fixture_sysctl
#define nanosleep fixture_sleep
#define main issue2_backend_main
#include "Issue2ButterflyTest.c"
#undef main
#include <assert.h>

static int manager_calls, opens, reads, writes, sleeps;
static int devices_count=1, signature_count=1, bad_descriptor;
static int vendor=0x05ac, product=0x027d, primary_page=1, primary_usage=6;
static IOReturn manager_error, open_error, read_error;
static int bad_configuration, write_failure, interrupt_pulse;
static const char *model_name="MacBookPro15,4";
static CFNumberRef properties[4];
static uint8_t sent[2][6];
IOHIDManagerRef fixture_manager_create(CFAllocatorRef allocator, IOOptionBits options) {
    (void)allocator;assert(options==0);manager_calls++;
    int value=999;return (IOHIDManagerRef)CFNumberCreate(NULL,kCFNumberIntType,&value);
}
void fixture_match(IOHIDManagerRef manager, CFDictionaryRef match) {
    assert(manager && match && CFDictionaryGetCount(match)==4);
    const CFStringRef keys[]={CFSTR(kIOHIDVendorIDKey),CFSTR(kIOHIDProductIDKey),CFSTR(kIOHIDPrimaryUsagePageKey),CFSTR(kIOHIDPrimaryUsageKey)};
    const int expected[]={0x05ac,0x027d,1,6};
    for(int i=0;i<4;i++){
        int value=0;CFNumberRef number=(CFNumberRef)CFDictionaryGetValue(match,keys[i]);
        assert(number && CFNumberGetValue(number,kCFNumberIntType,&value) && value==expected[i]);
    }
}
IOReturn fixture_manager_open(IOHIDManagerRef manager, IOOptionBits options) { assert(manager && options==0);return manager_error; }
IOReturn fixture_manager_close(IOHIDManagerRef manager, IOOptionBits options) { assert(manager && options==0);return kIOReturnSuccess; }
CFSetRef fixture_devices(IOHIDManagerRef manager) {
    assert(manager);
    CFMutableSetRef set=CFSetCreateMutable(NULL,0,&kCFTypeSetCallBacks);
    for(int i=1;i<=devices_count;i++){
        CFNumberRef device=CFNumberCreate(NULL,kCFNumberIntType,&i);CFSetAddValue(set,device);CFRelease(device);
    }
    return set;
}
CFTypeRef fixture_property(IOHIDDeviceRef device, CFStringRef key) {
    assert(device);
    const CFStringRef keys[]={CFSTR(kIOHIDVendorIDKey),CFSTR(kIOHIDProductIDKey),CFSTR(kIOHIDPrimaryUsagePageKey),CFSTR(kIOHIDPrimaryUsageKey)};
    const int values[]={vendor,product,primary_page,primary_usage};
    for(int i=0;i<4;i++)if(CFEqual(key,keys[i])){
        if(!properties[i])properties[i]=CFNumberCreate(NULL,kCFNumberIntType,values+i);
        return properties[i];
    }
    abort();
}
CFArrayRef fixture_elements(IOHIDDeviceRef device, CFDictionaryRef matching, IOOptionBits options) {
    assert(device && !matching && options==0);
    CFMutableArrayRef array=CFArrayCreateMutable(NULL,0,&kCFTypeArrayCallBacks);
    for(int i=0;i<signature_count;i++){
        CFNumberRef element=CFNumberCreate(NULL,kCFNumberIntType,&i);CFArrayAppendValue(array,element);CFRelease(element);
    }
    return array;
}
IOHIDElementType fixture_type(IOHIDElementRef element) { assert(element);return bad_descriptor==1?kIOHIDElementTypeFeature:kIOHIDElementTypeInput_Misc; }
uint32_t fixture_page(IOHIDElementRef element) { assert(element);return bad_descriptor==2?0xff12:0xff00; }
uint32_t fixture_usage(IOHIDElementRef element) { assert(element);return bad_descriptor==3?1:0xf; }
uint32_t fixture_id(IOHIDElementRef element) { assert(element);return bad_descriptor==4?0x01:0xbf; }
uint32_t fixture_bits(IOHIDElementRef element) { assert(element);return bad_descriptor==5?8:120; }
uint32_t fixture_count(IOHIDElementRef element) { assert(element);return bad_descriptor==6?1:15; }
CFIndex fixture_min(IOHIDElementRef element) { assert(element);return bad_descriptor==7?1:0; }
CFIndex fixture_max(IOHIDElementRef element) { assert(element);return bad_descriptor==8?254:255; }
IOReturn fixture_device_open(IOHIDDeviceRef device, IOOptionBits options) { assert(device && options==0);opens++;return open_error; }
IOReturn fixture_device_close(IOHIDDeviceRef device, IOOptionBits options) { assert(device && options==0);return kIOReturnSuccess; }
IOReturn fixture_get(IOHIDDeviceRef device, IOHIDReportType kind, CFIndex id, uint8_t *bytes, CFIndex *length) {
    assert(device && opens==1 && kind==kIOHIDReportTypeFeature && id==0xbf && *length==64);
    reads++;
    if(read_error)return read_error;
    const uint8_t config[]={0xbf,1,0,0,32,0,0,2};memcpy(bytes,config,8);*length=8;
    switch(bad_configuration){
        case 1:*length=7;break;
        case 2:*length=9;break;
        case 3:bytes[0]=1;break;
        case 4:bytes[1]=2;break;
        case 5:bytes[2]=1;break;
        case 6:bytes[4]=31;break;
        case 7:bytes[6]=1;break;
        case 8:*length=65;break;
    }
    return kIOReturnSuccess;
}
IOReturn fixture_set(IOHIDDeviceRef device, IOHIDReportType kind, CFIndex id, const uint8_t *bytes, CFIndex length) {
    assert(device && opens==1 && reads==1 && kind==kIOHIDReportTypeOutput && id==0xb0 && length==6 && writes<2);
    assert(bytes[0]==0xb0 && bytes[1]==1 && (bytes[2]==0 || bytes[2]==32) && bytes[3]==0 && bytes[4]==0 && bytes[5]==0);
    memcpy(sent[writes],bytes,6);writes++;
    return writes==write_failure?kIOReturnUnsupported:kIOReturnSuccess;
}
int fixture_sysctl(const char *name, void *data, size_t *length, void *new_data, size_t new_length) {
    assert(!strcmp(name,"hw.model") && !new_data && new_length==0 && *length>strlen(model_name));
    strcpy(data,model_name);*length=strlen(model_name)+1;return 0;
}
int fixture_sleep(const struct timespec *request, struct timespec *remaining) {
    assert(request->tv_sec==2 && request->tv_nsec==0);(void)remaining;sleeps++;
    if(interrupt_pulse==1){issue2_stop(SIGTERM);errno=EINTR;return -1;}
    if(interrupt_pulse==2){errno=EINVAL;return -1;}
    return 0;
}
int main(int argc, char **argv) {
    assert(argc==2);
    const char *name=argv[1];
    char *probe[]={"fixture","probe"};
    char *pulse[]={"fixture","pulse",ISSUE2_CONFIRM};
    char *off[]={"fixture","off",ISSUE2_CONFIRM};
    int result=0, expected=0, expected_writes=0;
    if(!strcmp(name,"probe"))result=issue2_backend_main(2,probe);
    else if(!strcmp(name,"default"))result=issue2_backend_main(1,probe);
    else if(!strcmp(name,"pulse")){result=issue2_backend_main(3,pulse);expected_writes=2;assert(sleeps==1 && sent[0][2]==32 && sent[1][2]==0);}
    else if(!strcmp(name,"off")){result=issue2_backend_main(3,off);expected_writes=1;assert(sent[0][2]==0 && sleeps==0);}
    else if(!strcmp(name,"no-confirmation")){result=issue2_backend_main(2,pulse);expected=2;assert(manager_calls==0);}
    else if(!strcmp(name,"wrong-confirmation")){pulse[2]="--confirm-probe=0:10:100";result=issue2_backend_main(3,pulse);expected=2;assert(manager_calls==0);}
    else if(!strcmp(name,"extra-probe-argument")){char *extra[]={"fixture","probe","extra"};result=issue2_backend_main(3,extra);expected=2;assert(manager_calls==0);}
    else if(!strcmp(name,"wrong-model")){model_name="MacBookPro16,1";result=issue2_backend_main(3,pulse);expected=3;assert(manager_calls==0);}
    else if(!strcmp(name,"unknown-product")){product=0x8102;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"unknown-vendor")){vendor=0x1234;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"wrong-primary-page")){primary_page=0xff00;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"wrong-primary-usage")){primary_usage=2;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"no-devices")){devices_count=0;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"ambiguous")){devices_count=2;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"duplicate-signature")){signature_count=2;result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strcmp(name,"manager-denied")){manager_error=kIOReturnNotPermitted;result=issue2_backend_main(3,pulse);expected=4;assert(opens==0);}
    else if(!strcmp(name,"device-denied")){open_error=kIOReturnNotPermitted;result=issue2_backend_main(3,pulse);expected=6;assert(reads==0);}
    else if(!strcmp(name,"get-unsupported")){read_error=kIOReturnUnsupported;result=issue2_backend_main(3,pulse);expected=7;}
    else if(!strncmp(name,"descriptor-",11)){bad_descriptor=atoi(name+11);assert(bad_descriptor>=1 && bad_descriptor<=8);result=issue2_backend_main(3,pulse);expected=5;assert(opens==0);}
    else if(!strncmp(name,"config-",7)){bad_configuration=atoi(name+7);assert(bad_configuration>=1 && bad_configuration<=8);result=issue2_backend_main(3,pulse);expected=7;}
    else if(!strcmp(name,"low-unsupported")){write_failure=1;result=issue2_backend_main(3,pulse);expected=8;expected_writes=1;assert(sleeps==0);}
    else if(!strcmp(name,"off-unsupported")){write_failure=2;result=issue2_backend_main(3,pulse);expected=8;expected_writes=2;}
    else if(!strcmp(name,"timer-failed")){interrupt_pulse=2;result=issue2_backend_main(3,pulse);expected=9;expected_writes=2;assert(sent[1][2]==0);}
    else if(!strcmp(name,"interrupted")){interrupt_pulse=1;result=issue2_backend_main(3,pulse);expected=9;expected_writes=2;assert(sent[1][2]==0);}
    else abort();
    assert(result==expected && writes==expected_writes);
    for(int i=0;i<4;i++)if(properties[i])CFRelease(properties[i]);
    puts("Fixture passed; no real HID APIs invoked.");
    return 0;
}
