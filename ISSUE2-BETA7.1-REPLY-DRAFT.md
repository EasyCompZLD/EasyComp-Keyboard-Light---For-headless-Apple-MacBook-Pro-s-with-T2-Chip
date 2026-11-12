# Draft reply — post only after beta7.1 is published

Hi @mjesticfalco,

Thanks again for confirming both visible minimum-light/off cycles! Beta7.1 now integrates that exact Butterfly protocol into the normal app and installer, with strict model/interface checks and a fresh configuration validation before each operation.

[Download the beta7.1 Setup app](https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip/releases/download/v1.2.0-beta7.1/EasyComp-Keyboard-Light-Beta.zip)

Please quit the isolated test app and any other keyboard-light controller, extract the ZIP locally, open **EasyComp Keyboard Light Setup.app**, choose your language and Install/Update. The experimental-model confirmation remains intentional; the installer must first pass its read-only HID check.

Could you check whether installation completes and the menu bar app appears, then test off/on and the 10%–100% brightness steps? App restart, idle timeout/restoration and sleep/wake are the next acceptance checks. Original Touch Bar behavior still needs its own test.

If anything fails, please share the local diagnostic report from Setup and describe what the actual lights did. Minimum/off is confirmed; we are keeping this issue open until the integrated installation and full brightness range have been accepted.
