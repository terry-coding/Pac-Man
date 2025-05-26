import SwiftUI

struct LeaderboardView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var records: [GameRecord] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(records.prefix(10)) { record in
                    HStack {
                        Text("\(formatTime(timeSpent: record.timeSpent))")
                            .font(.headline)
                        Spacer()
                        Text("Score: \(record.score)")
                        Text(formatDate(record.date))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            records = GameRecordManager.shared.getAllRecords()
        }
    }
    
    private func formatTime(timeSpent: Double) -> String {
        let minutes = Int(timeSpent) / 60
        let seconds = Int(timeSpent) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}