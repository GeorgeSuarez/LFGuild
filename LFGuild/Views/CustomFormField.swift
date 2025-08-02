//
//  CustomFormField.swift
//  LFGuild
//
//  Created by George Suarez on 8/1/25.
//

import SwiftUI

struct CustomFormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @FocusState.Binding var focused: RegistrationView.RegistrationField?
    let field: RegistrationView.RegistrationField
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure: Bool = false
    var showPasswordToggle: Bool = false
    @Binding var showPassword: Bool
    
    init(title: String, text: Binding<String>, placeholder: String,
         focused: FocusState<RegistrationView.RegistrationField?>.Binding,
         field: RegistrationView.RegistrationField,
         keyboardType: UIKeyboardType = .default,
         textContentType: UITextContentType? = nil,
         isSecure: Bool = false,
         showPasswordToggle: Bool = false,
         showPassword: Binding<Bool> = .constant(false)) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self._focused = focused
        self.field = field
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.isSecure = isSecure
        self.showPasswordToggle = showPasswordToggle
        self._showPassword = showPassword
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .focused($focused, equals: field)
                
                if showPasswordToggle {
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focused == field ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

#Preview {
}
