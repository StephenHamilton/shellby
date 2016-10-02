source "$botLib/irc.sh"

testIRCInfo() {
  declare -a data
  data=( $(getIRCInfo "JOIN
  assertEquals "shellby3" "${data[0]}"
  assertEquals "#shellbytest" "${data[1]}"
  assertEquals "JOIN" "${data[2]}"
  assertEquals "~Shellby" "${data[3]}"
  assertEquals "XXX-XXX.isp.com" "${data[4]}"
}
addTest testIRCInfo