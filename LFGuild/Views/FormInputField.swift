//
//  FormInputField.swift
//  LFGuild
//
//  Created by George Suarez on 6/28/26.
//

import SwiftUI

/// A reusable form input container with a title, leading icon, optional secure-entry toggle,
/// and a focus-aware border.
struct FormInputField<Content: View>: View {
    let title: String
    let icon: String
    let isSecure: Bool
    @Binding var isSecureVisible: Bool
    let isFocused: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        icon: String,
        isSecure: Bool = false,
        isSecureVisible: Binding<Bool> = .constant(false),
        isFocused: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.isSecure = isSecure
        self._isSecureVisible = isSecureVisible
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                content
                    .font(.body)

                if isSecure {
                    Button {
                        isSecureVisible.toggle()
                    } label: {
                        Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.gray.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isFocused ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1.5)
            }
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = ""
    @Previewable @State var showPassword = false
    @Previewable @FocusState var isEmailFocused: Bool
    @Previewable @FocusState var isPasswordFocused: Bool

    VStack(spacing: 20) {
        FormInputField(
            title: "Email",
            icon: "envelope",
            isFocused: isEmailFocused
        ) {
            TextField("name@example.com", text: $email)
                .textInputAutocapitalization(.never)
                .focused($isEmailFocused)
        }

        FormInputField(
            title: "Password",
            icon: "lock",
            isSecure: true,
            isSecureVisible: $showPassword,
            isFocused: isPasswordFocused
        ) {
            Group {
                if showPassword {
                    TextField("Enter your password", text: $password)
                } else {
                    SecureField("Enter your password", text: $password)
                }
            }
            .focused($isPasswordFocused)
        }
    }
    .padding()
}
