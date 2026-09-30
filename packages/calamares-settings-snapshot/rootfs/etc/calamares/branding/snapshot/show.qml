import QtQuick 2.0;
import calamares.slideshow 1.0;

// SnapshOT install slideshow. Ink background, lockup, short factual copy.
Presentation {
    id: presentation
    Timer { interval: 7000; running: true; repeat: true; onTriggered: presentation.goToNextSlide() }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0A0B0C" }
        Image {
            id: lockup
            source: "welcome.png"
            width: parent.width * 0.55
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.12
        }
        Rectangle {
            id: rule
            width: parent.width * 0.05; height: 2; color: "#F1000E"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: lockup.bottom; anchors.topMargin: parent.height * 0.07
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: rule.bottom; anchors.topMargin: parent.height * 0.07
            text: "Installing an OT assessment platform."
            color: "#F4F5F6"; font.pixelSize: parent.height * 0.045
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.08
            text: "Offline  ·  Encrypted  ·  Reproducible"
            color: "#8A8D91"; font.pixelSize: parent.height * 0.03
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0A0B0C" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -parent.height * 0.08
            text: "Offline by design"
            color: "#F1000E"; font.pixelSize: parent.height * 0.07; font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: parent.height * 0.04
            width: parent.width * 0.7; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
            text: "Nothing is fetched. The installer copies the live system to disk, so it works at an air-gapped site."
            color: "#F4F5F6"; font.pixelSize: parent.height * 0.038
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0A0B0C" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -parent.height * 0.08
            text: "Encrypted, then wiped"
            color: "#F1000E"; font.pixelSize: parent.height * 0.07; font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: parent.height * 0.04
            width: parent.width * 0.7; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
            text: "Full-disk LUKS2 encryption from the installer. Re-image between engagements to clear client data."
            color: "#F4F5F6"; font.pixelSize: parent.height * 0.038
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0A0B0C" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -parent.height * 0.08
            text: "Passive first"
            color: "#F1000E"; font.pixelSize: parent.height * 0.07; font.weight: Font.Medium
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: parent.height * 0.04
            width: parent.width * 0.7; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
            text: "Quiet on the wire by default. Interfaces come up when you bring them up."
            color: "#F4F5F6"; font.pixelSize: parent.height * 0.038
        }
    }
}
