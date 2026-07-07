# Device Connection Flow

This diagram documents the implemented DoseLatch device lifecycle across the iOS app, backend, and ESP32 firmware. It reflects the current Bluetooth onboarding path in code, not the older PRD alternatives.

Render it with:

```bash
dot -Tpng docs/device_connection_flow.dot -o /tmp/device_connection_flow.png
```

The graph covers add device, paired-device event upload, get device list, and remove device.
