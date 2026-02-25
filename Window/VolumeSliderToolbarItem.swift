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

        // Find the VolumeSlider that the button references via _popView outlet
        guard let volumeSlider = button.value(forKey: "_popView") as? NSSlider else { return }

        // Create a horizontal version of the volume slider
        let hSlider = HorizontalVolumeSlider(volumeSlider: volumeSlider)
        hSlider.translatesAutoresizingMaskIntoConstraints = false

        // Left speaker icon (low volume / mute)
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
        let stackView = NSStackView(views: [leftIcon, hSlider, rightIcon])
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
    }
}

// A horizontal slider that mirrors the value of the original vertical VolumeSlider
private class HorizontalVolumeSlider: NSSlider {

    private weak var originalSlider: NSSlider?
    private var observation: NSKeyValueObservation?

    convenience init(volumeSlider: NSSlider) {
        self.init()
        self.originalSlider = volumeSlider
        self.sliderType = .linear
        self.isVertical = false
        self.controlSize = .small
        self.minValue = volumeSlider.minValue
        self.maxValue = volumeSlider.maxValue
        self.doubleValue = volumeSlider.doubleValue
        self.isContinuous = true
        self.target = self
        self.action = #selector(sliderChanged(_:))

        // Observe changes on the original slider to keep in sync
        observation = volumeSlider.observe(\.doubleValue, options: [.new]) { [weak self] _, change in
            if let newValue = change.newValue {
                self?.doubleValue = newValue
            }
        }
    }

    @objc private func sliderChanged(_ sender: Any) {
        guard let original = originalSlider else { return }
        original.doubleValue = self.doubleValue
        // Trigger the original action (changeVolume: on PlaybackController)
        if let target = original.target, let action = original.action {
            _ = target.perform(action, with: original)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let change = event.deltaY + event.deltaX
        self.doubleValue += Double(change)
        sliderChanged(self)
    }
}
