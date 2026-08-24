// MUTHURKit — the record, before anything draws it.
//
// The domain layer: what a record is, where it came from, what its running
// order is, where its sleeve came from, and how much of it you had heard last
// time. No AppKit, no SwiftUI, nothing that needs a window — parity is won or
// lost in here, and it is testable only while that stays true.
//
// Empty on purpose. See docs/parity.md for what belongs in each folder:
//
//   Record/   §3  metadata, and the running order it dictates
//   Disc/     §1.3, §4  the TOC, and CD-Text → MusicBrainz → track numbers
//   Scratch/  §2  zips, and the scratch directory macOS will not reclaim
//   Sleeve/   §5  artwork: embedded first, then the network
//   Shelf/    §8  the collection annotation, read live and never written
//   Resume/   §7  where the needle was
