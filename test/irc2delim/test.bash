testTrivial() {
  assertDiff <( printf "TEST\r\n" ) <( printf "TEST\r\n" | irc2delim )
}
testSimple() {
  assertDiff <( printf "TEST\r\rtest\rtest test\n" ) <( printf "TEST test :test test\r\n" | irc2delim )
  assertDiff <( printf "TEST\r\rtest test\n" ) <( printf "TEST :test test\r\n" | irc2delim )
  assertDiff <( printf "TEST\r\rtest\rtest\rtest\n" ) <( printf "TEST test test test\r\n" | irc2delim )
  assertDiff <( printf "TEST\rwat\rtest\rtest\rtest\n" ) <( printf ":wat TEST test test test\r\n" | irc2delim )
  assertDiff <( printf "TEST\rwat\rtest test test\n" ) <( printf ":wat TEST :test test test\r\n" | irc2delim )
  assertDiff <( printf "TEST\rwat\n" ) <( printf ":wat TEST\r\n" | irc2delim )
}
addTest testTrivial
addTest testSimple
