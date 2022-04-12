package hacbs.contract.redhat

deny[msg] {
    name := data.failures[_].metadata.details.name
    not suppress(name)
    startswith(name, "com_redhat_")
	msg := sprintf("Failed Red Hat EC with: '%s'", [ name ])
}

suppress(name) {
	data.suppress["redhat-ec"][_] == name
}