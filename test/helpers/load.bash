# Load bats-assert / bats-support from Homebrew location.
load "/opt/homebrew/lib/bats-support/load.bash"
load "/opt/homebrew/lib/bats-assert/load.bash"

# Project root (one level above test/).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT
