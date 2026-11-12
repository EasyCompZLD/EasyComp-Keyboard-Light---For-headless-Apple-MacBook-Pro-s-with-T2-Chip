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
#define IOHIDDeviceConformsTo fixture_conforms
#define sysctlbyname fixture_sysctl
#define main production_backend_main
#include "HIDBacklight.c"
#undef main
#include <assert.h>

static int manager_calls, opens, reads, writes;
static int query_pid, magic, invalid_magic, magic_power=1;
static int devices_count=1, signature_count=1, bad_descriptor;
static int vendor=0x05ac, product=0x027d, primary_page=1, primary_usage=6;
static IOReturn manager_error, open_error, read_error;
static int bad_configuration, write_failure;
static const char *model_name="MacBookPro15,4";
static CFNumberRef properties[4];
static uint8_t sent[2][6];
IOHIDManagerRef fixture_manager_create(CFAllocatorRef allocator, IOOptionBits options) {
    (void)allocator;assert(options==0);manager_calls++;
    int value=999;return (IOHIDManagerRef)CFNumberCreate(NULL,kCFNumberIntType,&value);
}
void fixture_match(IOHIDManagerRef manager, CFDictionaryRef match) {
    assert(manager && match);
    int vid=0;
    assert(CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(match,CFSTR(kIOHIDVendorIDKey)),kCFNumberIntType,&vid));
    assert(vid==0x05ac);
    assert(CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(match,CFSTR(kIOHIDProductIDKey)),kCFNumberIntType,&query_pid));
    assert(query_pid==0x8102 || query_pid==0x0340 || query_pid==0x027c || query_pid==0x0276 || query_pid==0x027d);
    assert(CFDictionaryGetCount(match)==(query_pid==0x027d?4:2));
    if(query_pid==0x027d){
        int page=0,usage=0;
        assert(CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(match,CFSTR(kIOHIDPrimaryUsagePageKey)),kCFNumberIntType,&page));
        assert(CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(match,CFSTR(kIOHIDPrimaryUsageKey)),kCFNumberIntType,&usage));
        assert(page==1 && usage==6);
    }
}
IOReturn fixture_manager_open(IOHIDManagerRef manager, IOOptionBits options) { assert(manager && options==0);return manager_error; }
IOReturn fixture_manager_close(IOHIDManagerRef manager, IOOptionBits options) { assert(manager && options==0);return kIOReturnSuccess; }
CFSetRef fixture_devices(IOHIDManagerRef manager) {
    assert(manager);
    CFMutableSetRef set=CFSetCreateMutable(NULL,0,&kCFTypeSetCallBacks);
    for(int i=1;i<=(query_pid==(magic?0x8102:0x027d)?devices_count:0);i++){
        CFNumberRef device=CFNumberCreate(NULL,kCFNumberIntType,&i);CFSetAddValue(set,device);CFRelease(device);
    }
    return set;
}
CFTypeRef fixture_property(IOHIDDeviceRef device, CFStringRef key) {
    assert(device);
    const CFStringRef keys[]={CFSTR(kIOHIDVendorIDKey),CFSTR(kIOHIDProductIDKey),CFSTR(kIOHIDPrimaryUsagePageKey),CFSTR(kIOHIDPrimaryUsageKey)};
    const int values[]={vendor,magic?0x8102:product,magic?0xff00:primary_page,magic?0xf:primary_usage};
    for(int i=0;i<4;i++)if(CFEqual(key,keys[i])){
        if(!properties[i])properties[i]=CFNumberCreate(NULL,kCFNumberIntType,values+i);
        return properties[i];
    }
    abort();
}
CFArrayRef fixture_elements(IOHIDDeviceRef device, CFDictionaryRef matching, IOOptionBits options) {
    assert(device && !matching && options==0);
    CFMutableArrayRef array=CFArrayCreateMutable(NULL,0,&kCFTypeArrayCallBacks);
    for(int i=0;i<(magic?4:signature_count);i++){
        CFNumberRef element=CFNumberCreate(NULL,kCFNumberIntType,&i);CFArrayAppendValue(array,element);CFRelease(element);
    }
    return array;
}
static int fixture_index(IOHIDElementRef element) {
    int index=0;assert(CFNumberGetValue((CFNumberRef)element,kCFNumberIntType,&index));return index;
}
Boolean fixture_conforms(IOHIDDeviceRef device,uint32_t page,uint32_t usage){assert(device);return magic && page==0xff00 && usage==0xf;}
IOHIDElementType fixture_type(IOHIDElementRef element) { assert(element);return magic || bad_descriptor==1?kIOHIDElementTypeFeature:kIOHIDElementTypeInput_Misc; }
uint32_t fixture_page(IOHIDElementRef element) { assert(element);return bad_descriptor==2?0xff12:0xff00; }
uint32_t fixture_usage(IOHIDElementRef element) { assert(element);return bad_descriptor==3?1:0xf; }
uint32_t fixture_id(IOHIDElementRef element) { return magic?(fixture_index(element)<2?1:3):(bad_descriptor==4?0x01:0xbf); }
uint32_t fixture_bits(IOHIDElementRef element) { return magic?(fixture_index(element)==2?8:32):(bad_descriptor==5?8:120); }
uint32_t fixture_count(IOHIDElementRef element) { assert(element);return magic || bad_descriptor==6?1:15; }
CFIndex fixture_min(IOHIDElementRef element) { return magic?(fixture_index(element)==0?100:0):(bad_descriptor==7?1:0); }
CFIndex fixture_max(IOHIDElementRef element) {
    if(magic){int i=fixture_index(element);return i==0?(invalid_magic?512:14660):(i==2?1:65535);}
    return bad_descriptor==8?254:255;
}
IOReturn fixture_device_open(IOHIDDeviceRef device, IOOptionBits options) { assert(device && options==0);opens++;return open_error; }
IOReturn fixture_device_close(IOHIDDeviceRef device, IOOptionBits options) { assert(device && options==0);return kIOReturnSuccess; }
IOReturn fixture_get(IOHIDDeviceRef device, IOHIDReportType kind, CFIndex id, uint8_t *bytes, CFIndex *length) {
    assert(!magic && device && opens==1 && kind==kIOHIDReportTypeFeature && id==0xbf && *length==64);
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
    assert(device && opens==1 && writes<2);
    if(magic){
        assert(reads==0 && kind==kIOHIDReportTypeFeature);
        if(id==3){const uint8_t expected[]={3,(uint8_t)magic_power,0x5e,1,0,0};assert(length==6 && !memcmp(bytes,expected,6));}
        else {const uint8_t expected[]={1,0xa2,0x1c,0,0,0x5e,1,0,0};assert(id==1 && length==9 && !memcmp(bytes,expected,9));}
    }else{
        assert(reads==1 && kind==kIOHIDReportTypeOutput && id==0xb0 && length==6);
        assert(bytes[0]==0xb0 && bytes[1]==1 && bytes[4]==0 && bytes[5]==0);
        assert(read16(bytes+2)==0 || (read16(bytes+2)>=32 && read16(bytes+2)<=512));
        memcpy(sent[writes],bytes,6);
    }
    writes++;
    return writes==write_failure?kIOReturnUnsupported:kIOReturnSuccess;
}
int fixture_sysctl(const char *name, void *data, size_t *length, void *new_data, size_t new_length) {
    assert(!strcmp(name,"hw.model") && !new_data && new_length==0 && *length>strlen(model_name));
    strcpy(data,model_name);*length=strlen(model_name)+1;return 0;
}
int main(int argc,char **argv){
    assert(argc==2);
    const char *scenario=argv[1];
    char *args[]={"fixture","on","0.5"};
    int expected=0,expected_writes=1;
    if(!strcmp(scenario,"probe")){args[1]="probe";expected_writes=0;}
    else if(!strcmp(scenario,"diagnose")){args[1]="diagnose";expected_writes=0;}
    else if(!strcmp(scenario,"off")){args[1]="off";}
    else if(!strncmp(scenario,"level-",6)){args[2]=(char *)scenario+6;}
    else if(!strcmp(scenario,"wrong-model")){model_name="MacBookPro16,1";expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"unknown-product")){product=0x027b;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"unknown-vendor")){vendor=1;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"wrong-primary-page")){primary_page=0xff00;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"wrong-primary-usage")){primary_usage=2;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"ambiguous")){devices_count=2;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"duplicate-signature")){signature_count=2;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"no-devices")){devices_count=0;expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"manager-denied")){manager_error=kIOReturnNotPermitted;expected=4;expected_writes=0;}
    else if(!strcmp(scenario,"device-denied")){open_error=kIOReturnNotPermitted;expected=6;expected_writes=0;}
    else if(!strcmp(scenario,"get-unsupported")){read_error=kIOReturnUnsupported;expected=7;expected_writes=0;}
    else if(!strcmp(scenario,"write-unsupported")){write_failure=1;expected=8;}
    else if(!strncmp(scenario,"config-",7)){bad_configuration=atoi(scenario+7);expected=7;expected_writes=0;}
    else if(!strncmp(scenario,"descriptor-",11)){bad_descriptor=atoi(scenario+11);expected=5;expected_writes=0;}
    else if(!strcmp(scenario,"magic")){magic=1;expected_writes=2;model_name="MacBookPro16,1";}
    else if(!strcmp(scenario,"magic-off")){magic=1;magic_power=0;args[1]="off";expected_writes=1;model_name="MacBookPro16,1";}
    else if(!strcmp(scenario,"magic-probe")){magic=1;args[1]="probe";expected_writes=0;model_name="MacBookPro16,1";}
    else if(!strcmp(scenario,"magic-rejected")){magic=1;invalid_magic=1;expected=5;expected_writes=0;model_name="MacBookPro16,1";}
    else abort();
    int status=production_backend_main(!strcmp(args[1],"on")?3:2,args);
    assert(status==expected && writes==expected_writes);
    if(!magic && expected_writes){
        const uint16_t levels[]={0,51,102,154,205,256,307,358,410,461,512};
        int index=!strcmp(args[1],"off")?0:(int)(strtod(args[2],NULL)*10+0.5);
        assert(index>=0 && index<=10);uint16_t value=levels[index];
        assert(read16(sent[0]+2)==value);
    }
    if(!strcmp(scenario,"wrong-model"))assert(opens==0 && reads==0);
    if(!strcmp(scenario,"ambiguous"))assert(opens==0 && reads==0);
    for(int i=0;i<4;i++)if(properties[i])CFRelease(properties[i]);
    puts("Production fixture passed; no real HID APIs invoked.");return 0;
}
