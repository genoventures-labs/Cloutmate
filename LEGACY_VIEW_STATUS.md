## Legacy View Audit

- `NotesView` (`Cloutmate/Views/Notes/NotesView.swift`)  
  - **Status:** Deprecated (`@available` applied)  
  - **Replacement:** `UnifiedNotesView`

- `ListTableView` (`Cloutmate/Views/List/ListTableView.swift`)  
  - **Status:** Deprecated (`@available` applied)  
  - **Replacement:** V2 dashboards (`UnifiedProjectsView`, `UnifiedArtifactsView`, etc.)

- `QuickCaptureView` (`Cloutmate/Views/Capture/QuickCaptureView.swift`)  
  - **Status:** Deprecated (`@available` applied)  
  - **Replacement:** `QuickCaptureDrawer`

- Any future fallback additions should either adopt the V2 scaffolds (`V2GlassContentScaffold`, `GlassPanel`) or be explicitly marked deprecated with an accompanying migration path.


