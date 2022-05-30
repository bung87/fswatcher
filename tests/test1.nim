import std/[unittest, os]
import .. / src / fswatcher
import tempfile
suite "fswatcher":
  test "watch":
    let watcher = newFsWatcher()
    let temp = mkdtemp()
    let cb = proc (e: WatchEvent) =
      echo e
    echo temp
    watcher.watch(temp, cb)
    watcher.start()
