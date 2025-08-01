# Maintainer: Techcable <$USER @ techcable.net>
# Contributor: Kaizhao Zhang <zhangkaizhao@gmail.com>

pkgname=zig-dev-bin
# Old versions of zig-dev-bin used date as pkgver (pkgver=0.15.0_dev.1283.g1fcaf90dd
#x86_64-0.14.0_dev.15.d4bc64038
# Now we use something consistent with zig internal versioning.
# Without changing the epoch, the old version scheme would be considered
# "newer" greater than the new version scheme
epoch=1
# NOTE: Sanitize version '-' -> '_', '+' -> `.g`
#"version": "0.14.0-dev.829+2e26cf83c",
pkgver=0.15.0_dev.1283.g1fcaf90dd
pkgrel=1
pkgdesc="A general-purpose programming language and toolchain for maintaining robust, optimal, and reusable software"
arch=('x86_64' 'aarch64')
url="https://ziglang.org/"
license=('MIT')
makedepends=(curl jq minisign ripgrep)
options=('!strip')
provides=('zig')
conflicts=('zig')
# NOTE: We don't include the "real" source until build()
#
# The exception is our test file `hello.zig`
source=(
    "hello.zig"
)
# Hardcoded sha256 not possible because this is a an auto-updating (nightly) package
#
# Zig currently uses minisign to sign the binaries, which pacman doesn't support
# See zig issue for signed binaries: https://github.com/ziglang/zig/issues/4945
sha256sums=(
    "SKIP"
)

# https://ziglang.org/download/
ZIG_MINISIGN_KEY="RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U";

# Prints a warning message to stderr
warning() {
    echo -en "\e[33;1mWARNING\e[0m: " >&2;
    echo "$@" >&2;
}
error() {
    echo -en "\e[31;1mERROR\e[0m: " >&2;
    echo "$@" >&2;
}

# Fetch the version index, deleting any cached version.
refresh_version_index() {
    FORCE_REFRESH=1 fetch_version_index
}
# NOTE: If we put version-index in `source` then it would be cached
#
# Instead, fetch it by hand.
fetch_version_index() {
    local index_file="${srcdir}/zig-version-index.json";
    if [[ -f "$index_file" ]]; then
        if [[ $FORCE_REFRESH -eq 1 ]]; then
            # When ordered to 'refresh', we invalidate old verison-index.json
            echo "Deleting existing version index file (refreshing)" >&2;
            rm "$index_file";
        else
            echo $index_file;
            return 0;
        fi
    fi
    # Fallthrough to download index file
    echo "Downloading version index..." >&2;
    if ! curl -sS "https://ziglang.org/download/index.json" -o "$index_file"; then
        error "Failed to download version index";
        exit 1;
    else
        echo "Successfully downloaded version index (date: $(jq -r .master.date $index_file))" >&2;
    fi
    echo "$index_file"
}

# The original version of the zig package, without any sanitation
original_pkgver() {
    local index_file="$(fetch_version_index)"
    jq -r '.master.version' "$index_file";
}

# Sanitizes the package version, replacing special characters
#
# Specifically, we replace '-' with '_' because it's special-cased by makepkg & pacman,
# and replace '+$commit" with '.g$commit' because '+' is special-cased in URLs.
# Also the second form '.g$commit" is more consistent with the VCS package guidelines
# https://wiki.archlinux.org/title/VCS_package_guidelines#The_pkgver()_function
#
# Unlike VCS packages, there aren't really any clear guidelines on versioning
# for auto-updating binaries,
# so the versioning format of the package has changed somewhat over time.
pkgver() {
    (
        set -o pipefail;
        # Get the original version
        local origver="$(original_pkgver)"
        
        # Check if it's a release version (like 0.14.0)
        if [[ "$origver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$origver"
            return 0
        fi
        
        # Check if it's a dev version with the pattern X.X.X-devX.X+XXXXX
        if [[ "$origver" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(dev[0-9]+\.[0-9]+)\+([a-f0-9]+)$ ]]; then
            # Convert 0.14.0-dev.3429+13a9d94a8 to 0.14.0_dev.3429.g13a9d94a8
            echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}.g${BASH_REMATCH[3]}"
            return 0
        fi
        
        # If nothing else matched, try a more general approach for any version
        echo "$origver" | sed 's/-/_/g' | sed 's/+/.g/g' || {
            error "Failed to sanitize version: '$origver'";
            exit 1;
        }
    )
}

prepare() {
    local index_file="$(refresh_version_index)";
    local origver="$(original_pkgver)";
    pushd "${srcdir}" > /dev/null;
    local newurl="$(jq -r ".master.\"${CARCH}-linux\".tarball" $index_file)";
    local newurl_sig="$newurl.minisig";
    local newfile="zig-linux-${CARCH}-${origver}.tar.xz";
    local newfile_sig="$newfile.minisig";
    # NOTE: The Arch Build System unfortunately doesn't handle dynamically added sources.
    # source+=("${newfile}:${newurl}" "${newfile_sig}:${newurl_sig}")
    local expected_hash="$(jq -r ".master.\"${CARCH}-linux\".shasum" "$index_file")"
    # sha256sums+=("$expected_hash" "SKIP")
    if [[ -f "$newfile" && -f "$newfile_sig" ]]; then
        echo "Reusing existing $newfile (and signature)";
    else
        echo "Downloading Zig from $newurl";
        curl -Ss "$newurl" -o "$newfile";
        echo "Downloading signature...";
        curl -Ss "$newurl_sig" -o "$newfile_sig";
    fi;
    echo "" >&2;
    local actual_hash="$(sha256sum "$newfile" | grep -oE '^\w+')"
    if [[ "$expected_hash" != "$actual_hash" ]]; then
        error "Expected hash $expected_hash for $newfile, but got $actual_hash" >&2;
        exit 1;
    fi;
    echo "Using minisign to check signature";
    if ! minisign -V -P "$ZIG_MINISIGN_KEY" -m "$newfile" -x "$newfile_sig"; then
        error "Failed to check signature for $newfile" >&2;
        exit 1;
    fi
    echo "Extracting file";
    tar -xf "$newfile";
    popd > /dev/null;
}

RELATIVE_LANGREF_FILE="docs/langref.html";
# All of these must be present for
RELATIVE_STDLIB_DOC_FILES=("docs/std/index.html" "docs/std/main.js" "docs/std/data.js");
check() {
    hello_file="${srcdir}/hello.zig"
    # Zig caches (both local and global) can use up a lot of space.
    # For these hello world examples (in a frequently updated package), this is very wasteful.
    #
    # Right now there is no way to disable the cache (see Zig issue #12317)
    # Instead we shove everything in a local directory and delete it
    cache_dir="${srcdir}/zig-cache"
    local zig_dir="$(find_zig_directory)"
    cd "$zig_dir"
    echo "Running Zig Hello World"
    ./zig run --cache-dir "$cache_dir" --global-cache-dir "$cache_dir" "$hello_file"
    ./zig test --cache-dir "$cache_dir" --global-cache-dir "$cache_dir" "$hello_file"
    rm -rf "$cache_dir"
    rm -rf "$cache_dir";
    local missing_docs=();
    # Zig has had long-running issues with the location
    # of the docs directory.
    # See issue https://github.com/ziglang/zig/issues/9158
    #
    # We check that it's present, and warn otherwise
    # Alternative is failing the whole build just over docs
    if [[ ! -f "$RELATIVE_LANGREF_FILE" ]]; then
        missing_docs+=("langref.html");
    fi
    for stdlib_file in "${RELATIVE_STDLIB_DOC_FILES[@]}"; do
        if [[ ! -f "$stdlib_file" ]]; then
            missing_docs+=("stdlib["$(basename $stdlib_file)"]");
            break;
        fi
    done;
    if [[ "${#missing_docs[@]}" -ne 0 ]]; then
        warning "Missing documentation:" "${missing_docs[@]}";
        echo "This is likely related to Zig issue #9158: https://github.com/ziglang/zig/issues/9158" >&2;
        echo "Essentially, the docs locations are inconsistent across platofrms and builds." >&2;
        echo "This is especially true on non-linux platforms (and non x86_64)" >&2;
        echo "" >&2;
        echo "This will not impact execution, and you can always use the website docs: https://ziglang.org/documentation/master/" >&2;
    fi
}

# Helper function to find the extracted Zig directory
find_zig_directory() {
    echo "DEBUG: Searching for Zig directory in ${srcdir}" >&2
    echo "DEBUG: Contents of ${srcdir}:" >&2
    ls -la "${srcdir}" >&2
    
    # Look for directories matching the pattern zig-linux-*
    local zig_dir=$(find "${srcdir}" -maxdepth 1 -type d -name "zig-linux-*" | head -n1)
    
    if [[ -z "$zig_dir" ]]; then
        echo "DEBUG: No zig-linux-* directory found, looking for any zig* directory" >&2
        zig_dir=$(find "${srcdir}" -maxdepth 1 -type d -name "zig*" | head -n1)
    fi
    
    if [[ -z "$zig_dir" ]]; then
        echo "DEBUG: No zig* directory found, listing all directories" >&2
        find "${srcdir}" -maxdepth 1 -type d >&2
        error "Could not find extracted Zig directory in ${srcdir}"
        exit 1
    fi
    
    echo "DEBUG: Found Zig directory: $zig_dir" >&2
    echo "$zig_dir"
}

package() {
  local zig_dir="$(find_zig_directory)"
  echo "DEBUG: Using Zig directory: $zig_dir" >&2
  echo "DEBUG: Contents of Zig directory:" >&2
  ls -la "$zig_dir" >&2
  cd "$zig_dir"
  install -d "${pkgdir}/usr/bin"
  install -d "${pkgdir}/usr/lib/zig"
  cp -R lib "${pkgdir}/usr/lib/zig/lib"
  install -D -m755 zig "${pkgdir}/usr/lib/zig/zig"
  ln -s /usr/lib/zig/zig "${pkgdir}/usr/bin/zig"
  # Already gave warnings above, just silently ignore here
  if [[ -f "docs/langref.html" ]]; then
    install -D -m644 docs/langref.html "${pkgdir}/usr/share/doc/zig/langref.html"
  fi;
  if [[ -d "docs/std" ]]; then
    cp -R docs/std "${pkgdir}/usr/share/doc/zig/";
  fi
  install -D -m644 LICENSE "${pkgdir}/usr/share/licenses/zig/LICENSE"
}
