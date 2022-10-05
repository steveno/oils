#ifndef MARKSWEEP_H
#define MARKSWEEP_H

#include <unordered_set>
#include <vector>

class MarkSweepHeap;  // forward decl for circular dep

// The set of objects where the mark and sweep algorithm starts.  Terminology:
// to "root" an object means "add it to the root set".
class RootSet {
 public:
  explicit RootSet(int num_reserved) {
    stack_.reserve(num_reserved);  // e.g. 32 stack frames to start
    for (int i = 0; i < num_reserved; ++i) {
      stack_.emplace_back();      // Construct std::vector frame IN PLACE.
      stack_.back().reserve(16);  // Reserve 16 rooted variables per frame.
    }
  }

  // Called on function entry
  void PushScope() {
    // Construct more std::vector frames if necessary.  We reuse vectors to
    // avoid constructing one on every function call.
    int num_constructed = stack_.size();
    if (num_frames_ >= num_constructed) {
      stack_.emplace_back();
      stack_.back().reserve(16);
#if 0
      num_constructed = roots_.size();
      log("num_frames_ %d, num_constructed %d", num_frames_, num_constructed);
      assert(num_frames_ + 1 == num_constructed);
#endif
    }

    num_frames_++;
  }

  // Called on function exit
  void PopScope() {
    // Remove all roots owned by the top frame.  We're REUSING frames, so not
    // calling vector<>::pop().
    stack_[num_frames_ - 1].clear();
    num_frames_--;
  }

  // Called by MarkSweepHeap::OnProcessExit
  void Clear() {
    while (num_frames_ > 0) {
      PopScope();
    }
  }

  // Called when returning a value
  //
  // TODO: need RootOnThrow() too
  void RootOnReturn(Obj* root) {
    if (root == nullptr) {  // No reason to add it
      return;
    }

    // If we create temporaries in main(), then there's no "higher" stack frame
    // to free them.  To exit without leaks for ASAN, call
    // gHeap.OnProcessExit().
    if (num_frames_ <= 1) {
      return;
    }

    // Owned by the frame BELOW
    stack_[num_frames_ - 2].push_back(root);
  }

  // For testing
  int NumFrames() {
    return num_frames_;
  }

  // Calculate size of root set, for unit tests only.
  int NumRoots() {
    int result = 0;
    for (int i = 0; i < num_frames_; ++i) {
      result += stack_[i].size();
    }
    return result;
  }

  void MarkRoots(MarkSweepHeap* heap);

  // A stack of frames that's updated in parallel the call stack.
  // This representation is appropriate since multiple stack frames are "in
  // play" at once.  That is, RootOnReturn() may mutate root_set_[1] while
  // root_set_[2] is being pushed/popped/modified.
  std::vector<std::vector<Obj*>> stack_;
  int num_frames_ = 0;  // frames 0 to N-1 are valid
};

class MarkSweepHeap {
 public:
  // reserve 32 frames to start
  MarkSweepHeap() : root_set_(32) {
  }

  void Init();  // use default threshold
  void Init(int collect_threshold);

  //
  // OLD Local Var Rooting
  //

  void PushRoot(Obj** p) {
    roots_.push_back(p);
  }

  void PopRoot() {
    roots_.pop_back();
  }

  //
  // NEW Return Value Rooting
  //

  // Hopefully this will get inlined away
  void RootOnReturn(Obj* root) {
    root_set_.RootOnReturn(root);
    // Make the object a root until the CALLER returns
  }

  void* Allocate(int num_bytes);
  int Collect();
  void MarkObjects(Obj* obj);
  void Sweep();
  // Cleanup at the end of main() to remain ASAN-safe
  void OnProcessExit();

  void MaybePrintReport();
  void Report();

  // TODO(Jesse): This should really be in an 'internal' build
  bool is_initialized_ = true;  // mark/sweep doesn't need to be initialized

  // In number of live objects, since we aren't keeping track of total bytes
  int collect_threshold_;

  // Cumulative stats
  int64_t num_allocated_ = 0;
  int64_t bytes_allocated_ = 0;
  int64_t num_collections_ = 0;
  int max_live_ = 0;  // max # live after a collection

  // current stats
  int num_live_ = 0;
  // Should we keep track of sizes?
  // int64_t bytes_live_ = 0;

  // OLD rooting
  std::vector<Obj**> roots_;

  // NEW rooting
  RootSet root_set_;

  std::vector<void*> live_objs_;
  std::unordered_set<void*> marked_;

 private:
  DISALLOW_COPY_AND_ASSIGN(MarkSweepHeap);
};

#endif
