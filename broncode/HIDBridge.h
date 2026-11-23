#ifndef ECZ_HID_BRIDGE_H
#define ECZ_HID_BRIDGE_H
#include <stdint.h>
/* Execute the canonical backend. Setup passes read_only=1, rejecting all writes. */
int32_t ECZBacklightRun(const char *mode, const char *level, int32_t read_only);
#endif
