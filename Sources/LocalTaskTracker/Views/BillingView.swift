import SwiftUI

// MARK: - BillingView

struct BillingView: View {

    @State private var invoices:       [Invoice] = []
    @State private var offers:         [Offer]   = []
    @State private var billingTab:     BillingTab = .invoices
    @State private var showNewInvoice  = false
    @State private var showNewOffer    = false
    @State private var editInvoice:    Invoice?
    @State private var editOffer:      Offer?

    private enum BillingTab { case invoices, offers }

    // Derived groupings
    private var overdueInvoices: [Invoice] { invoices.filter { $0.isOverdue } }
    private var activeInvoices:  [Invoice] { invoices.filter { !$0.isOverdue && $0.status != .paid && $0.status != .cancelled } }
    private var closedInvoices:  [Invoice] { invoices.filter { $0.status == .paid || $0.status == .cancelled } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            summaryBar
            Divider()
            tabPicker
            Divider()
            if billingTab == .invoices {
                invoiceContent
            } else {
                offerContent
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showNewInvoice, onDismiss: load) {
            InvoiceEditorView { _ in load() }
        }
        .sheet(item: $editInvoice, onDismiss: load) { inv in
            InvoiceEditorView(existing: inv) { _ in load() }
        }
        .sheet(isPresented: $showNewOffer, onDismiss: load) {
            OfferEditorView { _ in load() }
        }
        .sheet(item: $editOffer, onDismiss: load) { offer in
            OfferEditorView(existing: offer) { _ in load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Billing").font(.title2.bold())
            Spacer()
            Button {
                if billingTab == .invoices { showNewInvoice = true }
                else { showNewOffer = true }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
    }

    // MARK: - Summary bar

    private var summaryBar: some View {
        HStack(spacing: 0) {
            summaryCell("Invoiced", total: totalFor(nil))
            Divider().frame(height: 32)
            summaryCell("Pending", total: totalFor([.sent, .pendingPayment]))
            Divider().frame(height: 32)
            summaryCell("Paid", total: totalFor([.paid]))
        }
        .padding(.vertical, 12)
    }

    private func summaryCell(_ title: String, total: String) -> some View {
        VStack(spacing: 3) {
            Text(total).font(.title3.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func totalFor(_ statuses: [InvoiceStatus]?) -> String {
        let filtered: [Invoice]
        if let statuses = statuses {
            filtered = invoices.filter { statuses.contains($0.status) }
        } else {
            filtered = invoices
        }
        if filtered.isEmpty { return "—" }
        var byCurrency: [String: Double] = [:]
        for inv in filtered { byCurrency[inv.currency, default: 0] += inv.amount }
        if byCurrency.count == 1, let (currency, amount) = byCurrency.first {
            return fmtAmount(amount, currency: currency)
        }
        return byCurrency.map { fmtAmount($0.value, currency: $0.key) }.joined(separator: " + ")
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            pickerButton("Invoices", tab: .invoices)
            pickerButton("Offers",   tab: .offers)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func pickerButton(_ label: String, tab: BillingTab) -> some View {
        Button { billingTab = tab } label: {
            Text(label)
                .font(.subheadline.weight(billingTab == tab ? .semibold : .regular))
                .foregroundStyle(billingTab == tab ? .primary : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    billingTab == tab ? Color.primary.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Invoice content

    @ViewBuilder
    private var invoiceContent: some View {
        if invoices.isEmpty {
            emptyState("No invoices yet.", systemImage: "doc.text")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !overdueInvoices.isEmpty {
                        invoiceSection("OVERDUE", invoices: overdueInvoices, titleColor: .red)
                    }
                    if !activeInvoices.isEmpty {
                        invoiceSection("ACTIVE", invoices: activeInvoices, titleColor: nil)
                    }
                    if !closedInvoices.isEmpty {
                        invoiceSection("CLOSED", invoices: closedInvoices, titleColor: nil)
                    }
                }
                .padding(20)
            }
        }
    }

    private func invoiceSection(_ title: String, invoices: [Invoice], titleColor: Color?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(titleColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
            ForEach(invoices) { invoice in
                InvoiceRow(invoice: invoice,
                           onEdit:   { editInvoice = invoice },
                           onDelete: { ProjectService.shared.deleteInvoice(invoice.id); load() })
            }
        }
    }

    // MARK: - Offer content

    @ViewBuilder
    private var offerContent: some View {
        if offers.isEmpty {
            emptyState("No offers yet.", systemImage: "envelope.open")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("OFFERS")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(offers) { offer in
                        OfferRow(offer: offer,
                                 onEdit:   { editOffer = offer },
                                 onDelete: { ProjectService.shared.deleteOffer(offer.id); load() })
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(_ message: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 36)).foregroundStyle(.tertiary)
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private func load() {
        invoices = ProjectService.shared.allInvoices()
        offers   = ProjectService.shared.allOffers()
    }
}

// MARK: - Shared amount formatter

private func fmtAmount(_ amount: Double, currency: String) -> String {
    let symbols = ["USD": "$", "EUR": "€", "GBP": "£", "CAD": "CA$", "AUD": "A$", "CHF": "Fr "]
    let sym = symbols[currency] ?? "\(currency) "
    if amount >= 1000 {
        return "\(sym)\(String(format: "%.0f", amount))"
    }
    return "\(sym)\(String(format: "%.2f", amount))"
}

// MARK: - InvoiceRow

struct InvoiceRow: View {
    let invoice: Invoice
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: invoice.projectColor))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.projectName)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Text(invoice.number)
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(fmtAmount(invoice.amount, currency: invoice.currency))
                    .font(.subheadline.monospacedDigit())
                if let due = invoice.dueDate {
                    Text(due, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(invoice.isOverdue ? .red : .secondary)
                }
            }

            InvoiceStatusBadge(status: invoice.status, isOverdue: invoice.isOverdue)

            HStack(spacing: 8) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.secondary)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - InvoiceStatusBadge

struct InvoiceStatusBadge: View {
    let status: InvoiceStatus
    let isOverdue: Bool

    var body: some View {
        Text(isOverdue ? "Overdue" : status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(badgeColor.opacity(0.12), in: Capsule())
    }

    private var badgeColor: Color {
        if isOverdue { return .red }
        switch status {
        case .draft:          return .gray
        case .sent:           return .blue
        case .pendingPayment: return .orange
        case .paid:           return .green
        case .cancelled:      return .gray
        }
    }
}

// MARK: - OfferRow

struct OfferRow: View {
    let offer: Offer
    let onEdit:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: offer.projectColor))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(offer.projectName)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Text(offer.title)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            if let amount = offer.amount {
                Text(fmtAmount(amount, currency: offer.currency))
                    .font(.subheadline.monospacedDigit())
            }

            if offer.filePath != nil {
                Image(systemName: "paperclip")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text(offer.createdAt, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption2).foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.secondary)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - InvoiceEditorView

struct InvoiceEditorView: View {
    var existing: Invoice? = nil
    var onDone: (Invoice) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var projects:          [Project]     = []
    @State private var selectedProjectID: Int?          = nil
    @State private var number             = ""
    @State private var amountText         = ""
    @State private var currency           = "USD"
    @State private var status             = InvoiceStatus.draft
    @State private var issuedDate         = Date()
    @State private var hasDueDate         = false
    @State private var dueDate            = Date().addingTimeInterval(30 * 86400)
    @State private var notes              = ""
    @State private var errorMsg           = ""

    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "CHF"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "New Invoice" : "Edit Invoice")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                label("Project")
                Picker("Project", selection: $selectedProjectID) {
                    Text("Select project…").tag(Optional<Int>.none)
                    ForEach(projects) { p in
                        Text(p.name).tag(Optional.some(p.id))
                    }
                }
                .labelsHidden()
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    label("Invoice #")
                    TextField("INV-001", text: $number).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    label("Status")
                    Picker("Status", selection: $status) {
                        ForEach(InvoiceStatus.allCases, id: \.self) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .labelsHidden()
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    label("Amount")
                    TextField("0.00", text: $amountText).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    label("Currency")
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { c in Text(c).tag(c) }
                    }
                    .labelsHidden().frame(width: 90)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Issued Date")
                DatePicker("", selection: $issuedDate, displayedComponents: .date).labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Set due date", isOn: $hasDueDate).font(.subheadline)
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date).labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Notes (optional)")
                TextField("Additional notes…", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(3, reservesSpace: true)
            }

            if !errorMsg.isEmpty {
                Text(errorMsg).font(.caption).foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.escape)
                Spacer()
                Button(existing == nil ? "Create" : "Save") { save() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return)
                    .disabled(selectedProjectID == nil || number.isEmpty || amountText.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 440, height: 580)
        .onAppear { setup() }
    }

    private func setup() {
        projects = ProjectService.shared.allProjects()
        if let inv = existing {
            selectedProjectID = inv.projectID
            number     = inv.number
            amountText = String(format: "%.2f", inv.amount)
            currency   = inv.currency
            status     = inv.status
            issuedDate = inv.issuedDate
            notes      = inv.notes ?? ""
            if let due = inv.dueDate { hasDueDate = true; dueDate = due }
        } else {
            selectedProjectID = projects.first?.id
            number = autoNumber()
        }
    }

    private func autoNumber() -> String {
        let y = Calendar.current.component(.year,  from: Date())
        let m = Calendar.current.component(.month, from: Date())
        return String(format: "INV-%04d-%02d-001", y, m)
    }

    private func save() {
        guard let projectID = selectedProjectID,
              let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
        else { errorMsg = "Please fill in all required fields."; return }

        if let inv = existing {
            var updated = inv
            updated.number     = number
            updated.amount     = amount
            updated.currency   = currency
            updated.status     = status
            updated.issuedDate = issuedDate
            updated.dueDate    = hasDueDate ? dueDate : nil
            updated.notes      = notes.isEmpty ? nil : notes
            ProjectService.shared.updateInvoice(updated)
            onDone(updated)
        } else {
            guard let created = ProjectService.shared.createInvoice(
                projectID:  projectID,
                number:     number,
                amount:     amount,
                currency:   currency,
                status:     status,
                issuedDate: issuedDate,
                dueDate:    hasDueDate ? dueDate : nil,
                notes:      notes.isEmpty ? nil : notes
            ) else { errorMsg = "Failed to save invoice."; return }
            onDone(created)
        }
        dismiss()
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
    }
}

// MARK: - OfferEditorView

struct OfferEditorView: View {
    var existing: Offer? = nil
    var onDone: (Offer) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var projects:          [Project] = []
    @State private var selectedProjectID: Int?      = nil
    @State private var title              = ""
    @State private var amountText         = ""
    @State private var currency           = "USD"
    @State private var filePath:          String?   = nil
    @State private var showFilePicker     = false
    @State private var errorMsg           = ""

    private let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "CHF"]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "New Offer" : "Edit Offer")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 6) {
                label("Project")
                Picker("Project", selection: $selectedProjectID) {
                    Text("Select project…").tag(Optional<Int>.none)
                    ForEach(projects) { p in
                        Text(p.name).tag(Optional.some(p.id))
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Title")
                TextField("e.g. Brand Design Proposal", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    label("Amount (optional)")
                    TextField("0.00", text: $amountText).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    label("Currency")
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { c in Text(c).tag(c) }
                    }
                    .labelsHidden().frame(width: 90)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                label("Document (optional)")
                HStack {
                    if let path = filePath {
                        Image(systemName: "paperclip").foregroundStyle(.secondary)
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Button("Remove") { filePath = nil }
                            .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.red)
                    } else {
                        Button("Choose File…") { showFilePicker = true }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }

            if !errorMsg.isEmpty {
                Text(errorMsg).font(.caption).foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.escape)
                Spacer()
                Button(existing == nil ? "Create" : "Save") { save() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return)
                    .disabled(selectedProjectID == nil || title.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 420, height: 440)
        .onAppear { setup() }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { filePath = url.path }
        }
    }

    private func setup() {
        projects = ProjectService.shared.allProjects()
        if let offer = existing {
            selectedProjectID = offer.projectID
            title    = offer.title
            currency = offer.currency
            filePath = offer.filePath
            if let amt = offer.amount { amountText = String(format: "%.2f", amt) }
        } else {
            selectedProjectID = projects.first?.id
        }
    }

    private func save() {
        guard let projectID = selectedProjectID, !title.isEmpty else {
            errorMsg = "Please fill in all required fields."; return
        }
        let amount = amountText.isEmpty
            ? nil
            : Double(amountText.replacingOccurrences(of: ",", with: "."))

        if let offer = existing {
            var updated = offer
            updated.title    = title
            updated.amount   = amount
            updated.currency = currency
            updated.filePath = filePath
            ProjectService.shared.updateOffer(updated)
            onDone(updated)
        } else {
            guard let created = ProjectService.shared.createOffer(
                projectID: projectID, title: title,
                amount: amount, currency: currency, filePath: filePath
            ) else { errorMsg = "Failed to save offer."; return }
            onDone(created)
        }
        dismiss()
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
    }
}
