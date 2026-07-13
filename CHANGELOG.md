## 1.0.0

- Initial release of the Canvas Editor engine: controller API, reactive state, text reflow, custom nodes, and PNG export.
- `onDocumentChanged` fires on committed changes only (gesture end / undo moments); use `stateStream` for live mid-drag updates.
