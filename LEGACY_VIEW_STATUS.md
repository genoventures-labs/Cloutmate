## Legacy View Audit

- `NotesView` (`FocusOS/Views/Notes/NotesView.swift`)  
  - **Status:** Deprecated (`@available` applied)  
  - **Replacement:** `UnifiedNotesView`

- `ListTableView` (`FocusOS/Views/List/ListTableView.swift`)  
  - **Status:** Deprecated (`@available` applied)  
  - **Replacement:** V2 dashboards (`UnifiedProjectsView`, `UnifiedArtifactsView`, etc.)

- `QuickCaptureView` (`FocusOS/Views/Capture/QuickCaptureView.swift`)  
  - **Status:** Deprecated (`@available` applied)  
  - **Replacement:** `QuickCaptureDrawer`

- Any future fallback additions should either adopt the V2 scaffolds (`V2GlassContentScaffold`, `GlassPanel`) or be explicitly marked deprecated with an accompanying migration path.


