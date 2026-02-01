import SwiftUI
import SwiftData

struct ClassOverviewGridView: View {
    
    @Bindable var schoolClass: SchoolClass
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 8) {
                
                // Header
                HStack {
                    Text("Student")
                        .frame(width: 120, alignment: .leading)
                    
                    ForEach(schoolClass.categories) { cat in
                        Text(cat.title)
                            .frame(width: 120)
                            .bold()
                    }

                }
                
                Divider()
                
                // Rows
                ForEach($schoolClass.students) { $student in
                    HStack {
                        Text(student.name)
                            .frame(width: 120, alignment: .leading)
                        
                        ForEach(student.scores.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                Text("\(student.scores[index].value)")
                                    .font(.headline)
                                    .frame(width: 30, alignment: .center)
                                
                                Stepper(
                                    "",
                                    value: $student.scores[index].value,
                                    in: 0...10
                                )
                                .labelsHidden()
                            }
                            .frame(width: 120)


                        }
                    }
                }

            }
            .padding()
        }
        .navigationTitle("Overview")
    }
}
