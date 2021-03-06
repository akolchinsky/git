#!/bin/sh

test_description='test untracked cache'

. ./test-lib.sh

avoid_racy() {
	sleep 1
}

# It's fine if git update-index returns an error code other than one,
# it'll be caught in the first test.
test_lazy_prereq UNTRACKED_CACHE '
	{ git update-index --untracked-cache; ret=$?; } &&
	test $ret -ne 1
'

if ! test_have_prereq UNTRACKED_CACHE; then
	skip_all='This system does not support untracked cache'
	test_done
fi

test_expect_success 'setup' '
	git init worktree &&
	cd worktree &&
	mkdir done dtwo dthree &&
	touch one two three done/one dtwo/two dthree/three &&
	git add one two done/one &&
	: >.git/info/exclude &&
	git update-index --untracked-cache
'

test_expect_success 'untracked cache is empty' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 0000000000000000000000000000000000000000
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
EOF
	test_cmp ../expect ../actual
'

cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? dthree/
?? dtwo/
?? three
EOF

cat >../dump.expect <<EOF &&
info/exclude e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ 0000000000000000000000000000000000000000 recurse valid
dthree/
dtwo/
three
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
three
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF

test_expect_success 'status first time (empty cache)' '
	avoid_racy &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 3
gitignore invalidation: 1
directory invalidation: 0
opendir: 4
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'untracked cache after first status' '
	test-dump-untracked-cache >../actual &&
	test_cmp ../dump.expect ../actual
'

test_expect_success 'status second time (fully populated cache)' '
	avoid_racy &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 0
opendir: 0
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'untracked cache after second status' '
	test-dump-untracked-cache >../actual &&
	test_cmp ../dump.expect ../actual
'

test_expect_success 'modify in root directory, one dir invalidation' '
	avoid_racy &&
	: >four &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? dthree/
?? dtwo/
?? four
?? three
EOF
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 1
opendir: 1
EOF
	test_cmp ../trace.expect ../trace

'

test_expect_success 'verify untracked cache dump' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ 0000000000000000000000000000000000000000 recurse valid
dthree/
dtwo/
four
three
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
three
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'new .gitignore invalidates recursively' '
	avoid_racy &&
	echo four >.gitignore &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? .gitignore
?? dthree/
?? dtwo/
?? three
EOF
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 1
directory invalidation: 1
opendir: 4
EOF
	test_cmp ../trace.expect ../trace

'

test_expect_success 'verify untracked cache dump' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude e69de29bb2d1d6434b8b29ae775ad8c2e48c5391
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dthree/
dtwo/
three
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
three
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'new info/exclude invalidates everything' '
	avoid_racy &&
	echo three >>.git/info/exclude &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? .gitignore
?? dtwo/
EOF
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 1
directory invalidation: 0
opendir: 4
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'verify untracked cache dump' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dtwo/
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'move two from tracked to untracked' '
	git rm --cached two &&
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'status after the move' '
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
?? .gitignore
?? dtwo/
?? two
EOF
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 0
opendir: 1
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'verify untracked cache dump' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dtwo/
two
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'move two from untracked to tracked' '
	git add two &&
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'status after the move' '
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	cat >../status.expect <<EOF &&
A  done/one
A  one
A  two
?? .gitignore
?? dtwo/
EOF
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 0
opendir: 1
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'verify untracked cache dump' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dtwo/
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'set up for sparse checkout testing' '
	echo two >done/.gitignore &&
	echo three >>done/.gitignore &&
	echo two >done/two &&
	git add -f done/two done/.gitignore &&
	git commit -m "first commit"
'

test_expect_success 'status after commit' '
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../actual &&
	cat >../status.expect <<EOF &&
?? .gitignore
?? dtwo/
EOF
	test_cmp ../status.expect ../actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 0
opendir: 2
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'untracked cache correct after commit' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dtwo/
/done/ 0000000000000000000000000000000000000000 recurse valid
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'set up sparse checkout' '
	echo "done/[a-z]*" >.git/info/sparse-checkout &&
	test_config core.sparsecheckout true &&
	git checkout master &&
	git update-index --force-untracked-cache &&
	git status --porcelain >/dev/null && # prime the cache
	test_path_is_missing done/.gitignore &&
	test_path_is_file done/one
'

test_expect_success 'create/modify files, some of which are gitignored' '
	echo two bis >done/two &&
	echo three >done/three && # three is gitignored
	echo four >done/four && # four is gitignored at a higher level
	echo five >done/five # five is not gitignored
'

test_expect_success 'test sparse status with untracked cache' '
	: >../trace &&
	avoid_racy &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../status.actual &&
	cat >../status.expect <<EOF &&
 M done/two
?? .gitignore
?? done/five
?? dtwo/
EOF
	test_cmp ../status.expect ../status.actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 1
directory invalidation: 2
opendir: 2
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'untracked cache correct after status' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dtwo/
/done/ 1946f0437f90c5005533cbe1736a6451ca301714 recurse valid
five
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'test sparse status again with untracked cache' '
	avoid_racy &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../status.actual &&
	cat >../status.expect <<EOF &&
 M done/two
?? .gitignore
?? done/five
?? dtwo/
EOF
	test_cmp ../status.expect ../status.actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 0
opendir: 0
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'set up for test of subdir and sparse checkouts' '
	mkdir done/sub &&
	mkdir done/sub/sub &&
	echo "sub" > done/sub/sub/file
'

test_expect_success 'test sparse status with untracked cache and subdir' '
	avoid_racy &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../status.actual &&
	cat >../status.expect <<EOF &&
 M done/two
?? .gitignore
?? done/five
?? done/sub/
?? dtwo/
EOF
	test_cmp ../status.expect ../status.actual &&
	cat >../trace.expect <<EOF &&
node creation: 2
gitignore invalidation: 0
directory invalidation: 1
opendir: 3
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'verify untracked cache dump (sparse/subdirs)' '
	test-dump-untracked-cache >../actual &&
	cat >../expect <<EOF &&
info/exclude 13263c0978fb9fad16b2d580fb800b6d811c3ff0
core.excludesfile 0000000000000000000000000000000000000000
exclude_per_dir .gitignore
flags 00000006
/ e6fcc8f2ee31bae321d66afd183fcb7237afae6e recurse valid
.gitignore
dtwo/
/done/ 1946f0437f90c5005533cbe1736a6451ca301714 recurse valid
five
sub/
/done/sub/ 0000000000000000000000000000000000000000 recurse check_only valid
sub/
/done/sub/sub/ 0000000000000000000000000000000000000000 recurse check_only valid
file
/dthree/ 0000000000000000000000000000000000000000 recurse check_only valid
/dtwo/ 0000000000000000000000000000000000000000 recurse check_only valid
two
EOF
	test_cmp ../expect ../actual
'

test_expect_success 'test sparse status again with untracked cache and subdir' '
	avoid_racy &&
	: >../trace &&
	GIT_TRACE_UNTRACKED_STATS="$TRASH_DIRECTORY/trace" \
	git status --porcelain >../status.actual &&
	test_cmp ../status.expect ../status.actual &&
	cat >../trace.expect <<EOF &&
node creation: 0
gitignore invalidation: 0
directory invalidation: 0
opendir: 0
EOF
	test_cmp ../trace.expect ../trace
'

test_expect_success 'move entry in subdir from untracked to cached' '
	git add dtwo/two &&
	git status --porcelain >../status.actual &&
	cat >../status.expect <<EOF &&
 M done/two
A  dtwo/two
?? .gitignore
?? done/five
?? done/sub/
EOF
	test_cmp ../status.expect ../status.actual
'

test_expect_success 'move entry in subdir from cached to untracked' '
	git rm --cached dtwo/two &&
	git status --porcelain >../status.actual &&
	cat >../status.expect <<EOF &&
 M done/two
?? .gitignore
?? done/five
?? done/sub/
?? dtwo/
EOF
	test_cmp ../status.expect ../status.actual
'

test_done
