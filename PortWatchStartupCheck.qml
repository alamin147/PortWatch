import QtQuick

import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand(
            "portWatch.depCheck",
            ["sh", "-c", "command -v bash >/dev/null && command -v ss >/dev/null && command -v hyprctl >/dev/null"],
            (stdout, exitCode) => {
                if (exitCode === 0) {
                    done(null)
                    return
                }

                done({
                    "title": "Port Watch requirements are missing",
                    "details": "Port Watch requires bash, ss (iproute2), and hyprctl."
                })
            }
        )
    }
}
