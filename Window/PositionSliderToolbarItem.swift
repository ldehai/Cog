//
//  PositionSliderToolbarItem.swift
//  Cog
//
//  Created by Dzmitry Neviadomski on 7.01.21.
//

import Cocoa

class PositionSliderToolbarItem: NSToolbarItem {

    private var titleLabel: NSTextField?
    private var containerView: NSView?
    private var didWrapView = false
    private var entryObservation: NSKeyValueObservation?

    override var minSize: NSSize {
        get { return NSSize(width: 100, height: 44) }
        set {}
    }

    override var maxSize: NSSize {
        get { return NSSize(width: 1024, height: 44) }
        set {}
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Defer wrapping to ensure XIB connections are fully established
        DispatchQueue.main.async { [weak self] in
            self?.wrapSliderIfNeeded()
        }
    }

    private func wrapSliderIfNeeded() {
        guard !didWrapView, let slider = self.view as? NSSlider else { return }
        didWrapView = true

        // --- Title Label (song name) ---
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.alignment = .center
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel = label

        // --- Container view (title on top, slider below) ---
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false

        // Use a vertical stack: center content vertically in the toolbar
        let stackView = NSStackView(views: [label, slider])
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            // Center the stack vertically within container
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            // Title label full width with small horizontal padding
            label.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: -4),

            // Slider full width
            slider.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            slider.heightAnchor.constraint(equalToConstant: 16),
        ])

        self.containerView = container
        self.view = container

        // --- Bind title label to current entry display ---
        bindTitleToCurrentEntry(slider: slider)
    }

    private func bindTitleToCurrentEntry(slider: NSSlider) {
        // The slider's maxValue is bound to currentEntryController.content.length
        // We can find the currentEntryController from that binding info
        guard let bindingInfo = slider.infoForBinding(NSBindingName("maxValue")),
              let controller = bindingInfo[.observedObject] as? NSObjectController else {
            return
        }
        // controller is the currentEntryController (NSObjectController)
        // Observe content.display for song title
        titleLabel?.bind(.value,
                         to: controller,
                         withKeyPath: "content.display",
                         options: [
                            .nullPlaceholder: "",
                            .notApplicablePlaceholder: "",
                            .noSelectionPlaceholder: ""
                         ])
    }
}
