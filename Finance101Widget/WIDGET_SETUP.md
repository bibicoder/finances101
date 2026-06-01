# Widget Setup — 5 steps in Xcode

## 1. Add Widget Extension target
File → New → Target → Widget Extension
- Product Name: Finance101Widget
- Include Configuration Intent: NO (uncheck)

## 2. Add App Group to BOTH targets
For "finances101" target AND "Finance101Widget" target:
- Signing & Capabilities → + → App Groups
- Add: group.com.finances101

## 3. Replace generated widget files
Delete the auto-generated .swift files in the Finance101Widget folder.
Copy in:
- Finance101Widget.swift
- Finance101WidgetView.swift

## 4. Remove @main from the main app if conflict
If build fails with "multiple @main", ensure finances101App.swift keeps @main
and Finance101Widget.swift keeps @main (each target has its own entry point — this is fine).

## 5. Build & run
The widget reads from group.com.finances101 UserDefaults.
The main app writes balance data on every HomeView refresh via WidgetDataWriter.
