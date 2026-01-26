# TODO - Next Steps

## Immediate Testing (Phase 2 Complete!)

- [ ] Build and run: `swift build && .build/debug/SURGE`
- [ ] Test Smart Care feature
  - [ ] Click "Smart Care" tab
  - [ ] Click "Run Smart Care"
  - [ ] Verify scan works
  - [ ] Verify cleanup works
  - [ ] Check results display
- [ ] Test Storage Management
  - [ ] Click "Storage" tab
  - [ ] Click "Scan" button
  - [ ] Select/deselect categories
  - [ ] Click "Review & Clean"
  - [ ] Preview items in modal
  - [ ] Confirm cleanup works
- [ ] Verify quarantine system works

## Phase 2 Cleanup (Optional)

- [ ] Add more tests for CleanupCoordinator
- [ ] Add tests for StorageViewModel and SmartCareViewModel
- [ ] Add integration tests for full cleanup workflow
- [ ] Performance testing (scan 100GB+)
- [ ] Memory leak testing (Instruments)

## Phase 3: Advanced Storage (Next 3 Weeks) 🎯

### Week 1: TreeMap Visualization
- [ ] Implement squarified TreeMap algorithm
- [ ] Create interactive drill-down navigation
- [ ] Add hover tooltips with file info
- [ ] Implement level-of-detail rendering
- [ ] Add color coding by file type
- [ ] Handle large datasets (10,000+ files)

### Week 2: Duplicate Finder & Large Files
- [ ] SHA-256 content hashing for duplicates
- [ ] Streaming file comparison
- [ ] Duplicate groups UI
- [ ] Large file finder (>100MB)
- [ ] Old file finder (>1 year)
- [ ] File preview capability

### Week 3: Application Uninstaller
- [ ] Detect installed applications
- [ ] Find associated files (caches, prefs, etc.)
- [ ] Complete uninstall capability
- [ ] Safety warnings for system apps
- [ ] Uninstall preview
- [ ] Performance optimization (scan 100GB in <30s)

- [ ] TreeMap disk space visualizer
- [ ] Interactive drill-down navigation
- [ ] Duplicate file finder (SHA-256 hashing)
- [ ] Large/old file identification
- [ ] Application uninstaller

## Long-Term Goals

- [ ] Community funding campaign for code signing certificate
- [ ] Malware signature database (community-driven)
- [ ] Localization support (i18n)
- [ ] Auto-update system (Sparkle integration)
- [ ] Scheduled cleanup tasks
- [ ] Performance benchmarks and optimization

## Documentation Needed

- [ ] Video tutorial for first-time users
- [ ] API documentation (DocC)
- [ ] Architecture decision records (ADRs)
- [ ] Security audit documentation
- [ ] Performance benchmarking guide

## Community Building

- [ ] Set up GitHub Discussions
- [ ] Create issue templates
- [ ] Set up GitHub Sponsors / Open Collective
- [ ] Write blog post announcing the project
- [ ] Create project website/landing page

---

**Current Status**: Phase 2 Complete ✅
**Next Milestone**: Phase 3 - Advanced Storage
**Timeline**: 3 weeks
