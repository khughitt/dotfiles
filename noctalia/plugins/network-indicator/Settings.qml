import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    readonly property var iconNames: ["arrow", "arrow-bar", "arrow-big", "arrow-narrow", "caret", "chevron", "chevron-compact", "fold"]

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string arrowType: cfg.arrowType || defaults.arrowType
    property int minWidth: cfg.minWidth || defaults.minWidth

    property bool useCustomColors: cfg.useCustomColors ?? defaults.useCustomColors
    property bool showNumbers: cfg.showNumbers ?? defaults.showNumbers
    property bool forceMegabytes: cfg.forceMegabytes ?? defaults.forceMegabytes

    property color colorSilent: root.useCustomColors && cfg.colorSilent || Color.mSurfaceVariant
    property color colorTx: root.useCustomColors && cfg.colorTx || Color.mSecondary
    property color colorRx: root.useCustomColors && cfg.colorRx || Color.mPrimary
    property color colorText: root.useCustomColors && cfg.colorText || Qt.alpha(Color.mOnSurfaceVariant, 0.3)
    property color colorBackground: root.useCustomColors && cfg.colorBackground || Style.capsuleColor

    property int byteThresholdActive: cfg.byteThresholdActive || defaults.byteThresholdActive
    property real fontSizeModifier: cfg.fontSizeModifier || defaults.fontSizeModifier
    property real iconSizeModifier: cfg.iconSizeModifier || defaults.iconSizeModifier
    property real spacingInbetween: cfg.spacingInbetween || defaults.spacingInbetween

    property string barPosition: Settings.data.bar.position || "top"
    property string barDensity: Settings.data.bar.density || "compact"
    property bool barIsSpacious: root.barDensity != "mini"
    property bool barIsVertical: root.barPosition === "left" || barPosition === "right"

    spacing: Style.marginL

    Component.onCompleted: {
        Logger.i("NetworkIndicator", "Settings UI loaded");
    }

    function toIntOr(defaultValue, text) {
        const v = parseInt(String(text).trim(), 10);
        return isNaN(v) ? defaultValue : v;
    }

    // ---------- General ----------

    RowLayout {
        NComboBox {
            label: pluginApi?.tr("settings.iconType.label")
            description: pluginApi?.tr("settings.iconType.desc")

            model: root.iconNames.map(function (n) {
                return {
                    key: n,
                    name: n
                };
            })

            currentKey: root.arrowType
            onSelected: key => root.arrowType = key
        }

        ColumnLayout {
            spacing: -10.0 + root.spacingInbetween

            NIcon {
                icon: arrowType + "-up"
                color: Color.mSecondary
                pointSize: Style.fontSizeL * root.iconSizeModifier
            }

            NIcon {
                icon: arrowType + "-down"
                color: Color.mPrimary
                pointSize: Style.fontSizeL * root.iconSizeModifier
            }
        }
    }

    NTextInput {
        label: pluginApi?.tr("settings.minWidth.label")
        description: pluginApi?.tr("settings.minWidth.desc")
        placeholderText: String(root.minWidth)
        text: String(root.minWidth)
        onTextChanged: root.minWidth = root.toIntOr(0, text)
    }

    NTextInput {
        label: pluginApi?.tr("settings.byteThresholdActive.label")
        description: pluginApi?.tr("settings.byteThresholdActive.desc")
        placeholderText: root.byteThresholdActive + " bytes"
        text: String(root.byteThresholdActive)
        onTextChanged: root.byteThresholdActive = root.toIntOr(0, text)
    }

    NToggle {
        label: pluginApi?.tr("settings.showNumbers.label")
        description: pluginApi?.tr("settings.showNumbers.desc")
        visible: barIsSpacious && !barIsVertical

        checked: root.showNumbers
        onToggled: function (checked) {
            root.showNumbers = checked;
        }
    }

    NToggle {
        label: pluginApi?.tr("settings.forceMegabytes.label")
        description: pluginApi?.tr("settings.forceMegabytes.desc")
        visible: barIsSpacious && !barIsVertical

        checked: root.forceMegabytes
        onToggled: function (checked) {
            root.forceMegabytes = checked;
        }
    }

    NDivider {
        visible: true
        Layout.fillWidth: true
        Layout.topMargin: Style.marginL
        Layout.bottomMargin: Style.marginL
    }

    // ---------- Slider ----------

    ColumnLayout {
        spacing: Style.marginXXS
        Layout.fillWidth: true

        NLabel {
            label: pluginApi?.tr("settings.spacingInbetween.label")
            description: pluginApi?.tr("settings.spacingInbetween.desc")
        }

        NValueSlider {
            Layout.fillWidth: true
            from: -5
            to: 5
            stepSize: 1
            value: root.spacingInbetween
            onMoved: value => root.spacingInbetween = value
            text: root.spacingInbetween.toFixed(0)
        }
    }

    ColumnLayout {
        spacing: Style.marginXXS
        Layout.fillWidth: true

        NLabel {
            label: pluginApi?.tr("settings.fontSizeModifier.label")
            description: pluginApi?.tr("settings.fontSizeModifier.desc")
        }

        NValueSlider {
            Layout.fillWidth: true
            from: 0.5
            to: 1.5
            stepSize: 0.05
            value: root.fontSizeModifier
            onMoved: value => root.fontSizeModifier = value
            text: fontSizeModifier.toFixed(2)
        }
    }

    ColumnLayout {
        spacing: Style.marginXXS
        Layout.fillWidth: true

        NLabel {
            label: pluginApi?.tr("settings.iconSizeModifier.label")
            description: pluginApi?.tr("settings.iconSizeModifier.desc")
        }

        NValueSlider {
            Layout.fillWidth: true
            from: 0.5
            to: 1.5
            stepSize: 0.05
            value: root.iconSizeModifier
            onMoved: value => root.iconSizeModifier = value
            text: root.iconSizeModifier.toFixed(2)
        }
    }

    NDivider {
        visible: true
        Layout.fillWidth: true
        Layout.topMargin: Style.marginL
        Layout.bottomMargin: Style.marginL
    }

    // ---------- Colors ----------

    NToggle {
        label: pluginApi?.tr("settings.useCustomColors.label")
        description: pluginApi?.tr("settings.useCustomColors.desc")
        checked: root.useCustomColors
        onToggled: function (checked) {
            root.useCustomColors = checked;
        }
    }

    ColumnLayout {
        visible: root.useCustomColors

        RowLayout {
            NLabel {
                label: pluginApi?.tr("settings.colorTx.label")
                description: pluginApi?.tr("settings.colorTx.desc")
                Layout.alignment: Qt.AlignTop
            }

            NColorPicker {
                selectedColor: root.colorTx
                onColorSelected: color => root.colorTx = color
            }
        }

        RowLayout {
            NLabel {
                label: pluginApi?.tr("settings.colorRx.label")
                description: pluginApi?.tr("settings.colorRx.desc")
            }

            NColorPicker {
                selectedColor: root.colorRx
                onColorSelected: color => root.colorRx = color
            }
        }

        RowLayout {
            NLabel {
                label: pluginApi?.tr("settings.colorSilent.label")
                description: pluginApi?.tr("settings.colorSilent.desc")
            }

            NColorPicker {
                selectedColor: root.colorSilent
                onColorSelected: color => root.colorSilent = color
            }
        }

        RowLayout {
            NLabel {
                label: pluginApi?.tr("settings.colorText.label")
                description: pluginApi?.tr("settings.colorText.desc")
            }

            NColorPicker {
                selectedColor: root.colorText
                onColorSelected: color => root.colorText = color
            }
        }

        RowLayout {
            NLabel {
                label: pluginApi?.tr("settings.colorBackground.label")
                description: pluginApi?.tr("settings.colorBackground.desc")
            }

            NColorPicker {
                selectedColor: root.colorBackground
                onColorSelected: color => root.colorBackground = color
            }
        }
    }

    // ---------- Saving ----------

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("NetworkIndicator", "Cannot save settings: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.useCustomColors = root.useCustomColors;
        pluginApi.pluginSettings.showNumbers = root.showNumbers;
        pluginApi.pluginSettings.forceMegabytes = root.forceMegabytes;

        pluginApi.pluginSettings.arrowType = root.arrowType;
        pluginApi.pluginSettings.minWidth = root.minWidth;
        pluginApi.pluginSettings.byteThresholdActive = root.byteThresholdActive;
        pluginApi.pluginSettings.fontSizeModifier = root.fontSizeModifier;
        pluginApi.pluginSettings.iconSizeModifier = root.iconSizeModifier;
        pluginApi.pluginSettings.spacingInbetween = root.spacingInbetween;

        if (root.useCustomColors) {
            pluginApi.pluginSettings.colorSilent = root.colorSilent.toString();
            pluginApi.pluginSettings.colorTx = root.colorTx.toString();
            pluginApi.pluginSettings.colorRx = root.colorRx.toString();
            pluginApi.pluginSettings.colorText = root.colorText.toString();
            pluginApi.pluginSettings.colorBackground = root.colorBackground.toString();
        }

        pluginApi.saveSettings();

        Logger.i("NetworkIndicator", "Settings saved successfully");
    }
}
