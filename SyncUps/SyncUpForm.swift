import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

@Reducer
struct SyncUpForm {
    @ObservableState
    struct State: Equatable, Sendable {
        var focus: Field? = .title
        var syncUp: SyncUp
        var attendeeFormIsPresented:  Bool
        
        init(focus: Field? = .title, syncUp: SyncUp, attendeeFormIsPresented: Bool = false) {
            self.focus = focus
            self.syncUp = syncUp
            self.attendeeFormIsPresented = attendeeFormIsPresented
            if self.syncUp.attendees.isEmpty {
                @Dependency(\.uuid) var uuid
                self.syncUp.attendees.append(Attendee(id: Attendee.ID(uuid())))
            }
        }
        
        enum Field: Hashable {
            case title
        }
    }
    
    enum Action: BindableAction, Equatable, Sendable {
        case addAttendeeButtonTapped
        case attendeeCreated(Attendee)
        case attendeeFormDismissed
        case binding(BindingAction<State>)
        case deleteAttendees(atOffsets: IndexSet)
    }
    
    @Dependency(\.uuid) var uuid
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .addAttendeeButtonTapped:
                let attendee = Attendee(id: Attendee.ID(uuid()))
                state.attendeeFormIsPresented = true
                return .none
                
            case .attendeeCreated(let attendee):
                state.syncUp.attendees.append(attendee)
                return .none
                
            case .attendeeFormDismissed:
                state.attendeeFormIsPresented = false
                return .none
                
            case .binding:
                return .none
                
            case let .deleteAttendees(atOffsets: indices):
                state.syncUp.attendees.remove(atOffsets: indices)
                if state.syncUp.attendees.isEmpty {
                    state.syncUp.attendees.append(Attendee(id: Attendee.ID(uuid())))
                }
                guard let firstIndex = indices.first
                else { return .none }
                let index = min(firstIndex, state.syncUp.attendees.count - 1)
                return .none
            }
        }
    }
}

struct SyncUpFormView: View {
    @Bindable var store: StoreOf<SyncUpForm>
    @FocusState var focus: SyncUpForm.State.Field?
    
    var body: some View {
        Form {
            Section {
                TextField("Title", text: $store.syncUp.title)
                    .focused($focus, equals: .title)
                HStack {
                    Slider(value: $store.syncUp.duration.minutes, in: 5...30, step: 1) {
                        Text("Length")
                    }
                    Spacer()
                    Text(store.syncUp.duration.formatted(.units()))
                }
                ThemePicker(selection: $store.syncUp.theme)
            } header: {
                Text("Sync-up Info")
            }
            Section {
                ForEach(store.syncUp.attendees) { attendee in
                    Text(attendee.name)
                }
                .onDelete { indices in
                    store.send(.deleteAttendees(atOffsets: indices))
                }
                
                Button("New attendee") {
                    store.send(.addAttendeeButtonTapped)
                }
            } header: {
                Text("Attendees")
            }
        }
        .sheet(
            isPresented: $store.attendeeFormIsPresented,
            onDismiss: {
                store.send(.attendeeFormDismissed)
            },
            content: {
                AttendeeForm { attendee in
                    store.send(.attendeeCreated(attendee))
                }
            }
        )
        .bind($store.focus, to: $focus)
    }
}

struct ThemePicker: View {
    @Binding var selection: Theme
    
    var body: some View {
        Picker("Theme", selection: $selection) {
            ForEach(Theme.allCases) { theme in
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.mainColor)
                    Label(theme.name, systemImage: "paintpalette")
                        .padding(4)
                }
                .foregroundColor(theme.accentColor)
                .fixedSize(horizontal: false, vertical: true)
                .tag(theme)
            }
        }
    }
}

extension Duration {
    fileprivate var minutes: Double {
        get { Double(components.seconds / 60) }
        set { self = .seconds(newValue * 60) }
    }
}

#Preview {
    NavigationStack {
        SyncUpFormView(
            store: Store(initialState: SyncUpForm.State(syncUp: .mock)) {
                SyncUpForm()
            }
        )
    }
}
