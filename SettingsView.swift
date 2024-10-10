import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Binding var isShowing: Bool
    @Binding var userId: Int?
    @State private var animeReminders: [AnimeReminder] = []
    @State private var showAddReminder = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Changer l'icône")) {
                    Button(action: {
                        changeAppIcon(to: "AppIcon2")
                    }) {
                        HStack {
                            Image("AppIconIMG1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                            Text("Icône 1")
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    Button(action: {
                        changeAppIcon(to: "AppIcon3")
                    }) {
                        HStack {
                            Image("AppIconIMG2")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                            Text("Icône 2")
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                
                Section(header: Text("Rappels d'anime")) {
                    Button(action: {
                        showAddReminder = true
                    }) {
                        Text("Ajouter un rappel")
                            .foregroundColor(.blue)
                    }
                    
                    ForEach(animeReminders) { reminder in
                        HStack {
                            Text("\(reminder.animeName) - \(reminder.dayName()) \(reminder.timeString())")
                            Spacer()
                            Button(action: {
                                deleteReminder(reminder: reminder)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                    
                Section {
                    Button(action: {
                        userId = nil
                        isShowing = false
                    }) {
                        Text("Déconnexion")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Fermer") {
                isShowing = false
            })
            .sheet(isPresented: $showAddReminder) {
                AddReminderView(animeReminders: $animeReminders, saveReminders: saveReminders)
            }
            .onAppear {
                loadReminders() // Charger les rappels à l'apparition de la vue
            }
        }
    }

    func changeAppIcon(to iconName: String) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Erreur lors du changement d'icône : \(error)")
            } else {
                print("Icône changée avec succès !")
            }
        }
    }
    
    func deleteReminder(reminder: AnimeReminder) {
        animeReminders.removeAll { $0.id == reminder.id }
        saveReminders() // Sauvegarder après la suppression
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.notificationId])
    }

    // Fonction pour sauvegarder les rappels dans UserDefaults
    func saveReminders() {
        let encoder = JSONEncoder()
        if let encodedReminders = try? encoder.encode(animeReminders) {
            UserDefaults.standard.set(encodedReminders, forKey: "animeReminders")
        }
    }

    // Fonction pour charger les rappels depuis UserDefaults
    func loadReminders() {
        if let savedRemindersData = UserDefaults.standard.data(forKey: "animeReminders") {
            let decoder = JSONDecoder()
            if let loadedReminders = try? decoder.decode([AnimeReminder].self, from: savedRemindersData) {
                animeReminders = loadedReminders
            }
        }
    }
}

struct AddReminderView: View {
    @Binding var animeReminders: [AnimeReminder]
    @State private var animeName: String = ""
    @State private var selectedDay: Int = 1
    @State private var selectedHour: Int = 20
    @State private var selectedMinute: Int = 0
    @Environment(\.presentationMode) var presentationMode
    var saveReminders: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nom de l'anime")) {
                    TextField("Nom", text: $animeName)
                }
                
                Section(header: Text("Jour de sortie")) {
                    Picker("Jour", selection: $selectedDay) {
                        ForEach(1...7, id: \.self) { day in
                            Text(dayName(for: day)).tag(day)
                        }
                    }
                }
                
                Section(header: Text("Heure de sortie")) {
                    HStack {
                        Picker("Heure", selection: $selectedHour) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        
                        Picker("Minute", selection: $selectedMinute) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                    }
                }
                
                Button("Ajouter Rappel") {
                    let newReminder = AnimeReminder(animeName: animeName, day: selectedDay, hour: selectedHour, minute: selectedMinute)
                    animeReminders.append(newReminder)
                    saveReminders() // Sauvegarder après l'ajout du rappel
                    scheduleNotification(for: newReminder)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Ajouter un rappel")
            .navigationBarItems(trailing: Button("Annuler") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    func dayName(for day: Int) -> String {
        let daysInFrench = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
        return daysInFrench[day - 1]
    }

    func scheduleNotification(for reminder: AnimeReminder) {
        let content = UNMutableNotificationContent()
        content.title = "Sortie d'un nouvel épisode"
        content.body = "L'anime \(reminder.animeName) est disponible!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = reminder.day
        dateComponents.hour = reminder.hour
        dateComponents.minute = reminder.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.notificationId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur lors de la planification de la notification: \(error)")
            } else {
                print("Notification planifiée avec succès pour \(reminder.animeName)")
            }
        }
    }
}

struct AnimeReminder: Identifiable, Codable {
    var id = UUID()
    var animeName: String
    var day: Int
    var hour: Int
    var minute: Int

    var notificationId: String {
        return id.uuidString
    }

    func dayName() -> String {
        let daysInFrench = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
        return daysInFrench[day - 1]
    }

    func timeString() -> String {
        return String(format: "%02dh%02dm", hour, minute)
    }
}
