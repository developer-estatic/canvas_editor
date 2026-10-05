## 1.2.0

### Added
- Web support. The engine compiles and runs in the browser. Resolve images with `assetId` and `imageProvider` (`NetworkImage`, `AssetImage`, or `MemoryImage`). `localPath` file reads stay on Android, iOS, and desktop.

### Fixed
- Inline text editing no longer paints the node twice. The canvas hides that node's glyphs while the field is open, and the field uses the node's font, size, line height, and letter spacing instead of the Host theme.
- Image loading awaits the decoded frame so a failed asset resolve is caught instead of returned as an unawaited `Future`.

### Changed
- `equatable` constraint is `^3.0.0`.

## 1.1.0

### Added
- Document Color helpers: `encodeDocumentColor` / `decodeDocumentColor` (`Color` ↔ `#AARRGGBB`).
- Per-Controller custom Node registry: types passed via `customNodeTypes` stay on that Controller; use `customNodeRegistry` or `documentFromJson` when parsing custom types.
- README clarifications: platform support (Web not supported), fit-to-parent canvas (no zoom/pan API), fonts, when `imageProvider` is required, and Background Fill replace behavior on `updateBackground`.

### Changed
- New Text Nodes default to the platform font (`fontFamily: null`) instead of `Inter`. Documents that already set `Inter` are unchanged.
- Docs describe inline text edit as tap a selected text node again (not double-tap).

### Deprecated
- `CanvasEditorState.hasUnsavedChanges` — this reflected undo stack depth, not unsaved work. Track dirty state with `onDocumentChanged`. Removed in 2.0.
- Static `CustomNodeRegistry.register` / `registerAll` / `get` / `all` — pass `customNodeTypes` to the Controller instead. Removed in 2.0.

### Removed
- Unused `cupertino_icons` dependency.

## 1.0.0

- Initial release of the Canvas Editor engine: controller API, reactive state, text reflow, custom nodes, and PNG export.
- `onDocumentChanged` fires on committed changes only (gesture end / undo moments); use `stateStream` for live mid-drag updates.
