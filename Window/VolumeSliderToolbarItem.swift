//
//  VolumeSliderToolbarItem.swift
//  Cog
//
//  Inline horizontal volume slider with speaker icons on both sides.
//

import Cocoa

class VolumeSliderToolbarItem: NSToolbarItem {

    private var containerView: NSView?
    private var didWrapView = false
    private var hSlider: NSSlider?
    private var observation: NSKeyValueObservation?

    override var minSize: NSSize {
        get { return NSSize(width: 120, height: 28) }
        set {}
    }

    override var maxSize: NSSize {
        get { return NSSize(width: 200, height: 28) }
        set {}
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        DispatchQueue.main.async { [weak self] in
            self?.wrapSliderIfNeeded()
        }
    }

    private func wrapSliderIfNeeded() {
        guard !didWrapView, let button = self.view as? NSButton else { return }
        didWrapView = true

        // Find the original VolumeSlider via VolumeButton's _popView ivar
        let volumeSlider = button.value(forKey: "_popView") as? NSSlider

        // Create a new horizontal slider
        let slider = VolumeHorizontalSlider()
        slider.toolbarItem = self
        slider.sliderType = .linear
        slider.isVertical = false
        slider.controlSize = .small
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.isContinuous = true
        slider.minValue = 0
        slider.maxValue = 100

        if let vs = volumeSlider {
            slider.doubleValue = vs.doubleValue
            slider.target = self
            slider.action = #selector(horizontalSliderChanged(_:))

            // Observe original slider value changes (from keyboard shortcuts, scroll, etc.)
            observation = vs.observe(\.doubleValue, options: [.new]) { [weak slider] _, change in
                if let newVal = change.newValue {
                    DispatchQueue.main.async {
                        slider?.doubleValue = newVal
                    }
                }
            }

            // Re-sync after all awakeFromNib calls have completed
            // PlaybackController sets the real value in its own awakeFromNib,
            // which may run after ours
            DispatchQueue.main.async { [weak slider, weak vs] in
                if let s = slider, let v = vs {
                    s.doubleValue = v.doubleValue
                }
                // And once more slightly later to catch any late initialization
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak slider, weak vs] in
                    if let s = slider, let v = vs {
                        s.doubleValue = v.doubleValue
                    }
                }
            }
        } else {
            slider.doubleValue = 55
        }

        self.hSlider = slider

        // Left speaker icon (mute/low)
        let leftIcon = NSImageView()
        leftIcon.translatesAutoresizingMaskIntoConstraints = false
        leftIcon.image = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Low volume")
        leftIcon.contentTintColor = .secondaryLabelColor
        leftIcon.setContentHuggingPriority(.required, for: .horizontal)
        leftIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            leftIcon.widthAnchor.constraint(equalToConstant: 14),
            leftIcon.heightAnchor.constraint(equalToConstant: 14),
        ])

        // Right speaker icon (high volume)
        let rightIcon = NSImageView()
        rightIcon.translatesAutoresizingMaskIntoConstraints = false
        rightIcon.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "High volume")
        rightIcon.contentTintColor = .secondaryLabelColor
        rightIcon.setContentHuggingPriority(.required, for: .horizontal)
        rightIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            rightIcon.widthAnchor.constraint(equalToConstant: 18),
            rightIcon.heightAnchor.constraint(equalToConstant: 14),
        ])

        // Horizontal stack: [speaker_low] [slider] [speaker_high]
        let stackView = NSStackView(views: [leftIcon, slider, rightIcon])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
        ])

        self.containerView = container
        self.view = container

        // Store volumeSlider reference for the action
        objc_setAssociatedObject(self, &kVolumeSliderKey, volumeSlider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc fileprivate func horizontalSliderChanged(_ sender: NSSlider) {
        guard let original = objc_getAssociatedObject(self, &kVolumeSliderKey) as? NSSlider else { return }
        original.doubleValue = sender.doubleValue
        // Use the original slider's target/action, or fall back to sendAction
        if let target = original.target, let action = original.action {
            _ = target.perform(action, with: original)
        } else {
            // Try sending action directly through responder chain
            NSApp.sendAction(Selector(("changeVolume:")), to: nil, from: original)
        }
    }
}

// Custom NSSlider subclass that forwards scroll wheel events to the volume system
private class VolumeHorizontalSlider: NSSlider {
    weak var toolbarItem: VolumeSliderToolbarItem?

    override func scrollWheel(with event: NSEvent) {
        let change = Double(event.deltaY + event.deltaX)
        self.doubleValue = max(self.minValue, min(self.maxValue, self.doubleValue + change))
        toolbarItem?.horizontalSliderChanged(self)
    }
}

private var kVolumeSliderKey: UInt8 = 0
