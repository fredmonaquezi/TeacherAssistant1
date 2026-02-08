import Foundation
import SwiftData

@MainActor
func createDefaultRubrics(context: ModelContext) {
    // Quick check if templates already exist - exit immediately if they do
    let descriptor = FetchDescriptor<RubricTemplate>()
    do {
        let count = try context.fetchCount(descriptor)
        if count > 0 {
            SecureLogger.debug("Default rubrics already exist (\(count) templates), skipping initialization")
            return
        }
    } catch {
        SecureLogger.warning("Could not check existing rubrics: \(error)")
        // Continue with creation anyway
    }

    SecureLogger.debug("Creating default rubric templates...")
    
    // PRIMARY (Years 1-3)
    createPrimaryTemplates(context: context)
    
    // INTERMEDIATE (Years 4-6)
    createIntermediateTemplates(context: context)
    
    // SECONDARY (Years 7-9)
    createSecondaryTemplates(context: context)
    
    // HIGH SCHOOL (Years 10-12)
    createHighSchoolTemplates(context: context)
    
    try? context.save()
    SecureLogger.debug("Default rubric templates created successfully")
}

// MARK: - PRIMARY (Years 1-3)

func createPrimaryTemplates(context: ModelContext) {
    // English Language
    let englishTemplate = RubricTemplate(
        name: "Primary English Language (Years 1-3)",
        gradeLevel: "Years 1-3",
        subject: "English"
    )
    
    let listening = RubricCategory(name: "Listening and Comprehension")
    listening.criteria = [
        RubricCriterion(name: "Follows Class Instructions", details: "Student listens and follows multi-step directions"),
        RubricCriterion(name: "Understands Spoken Narratives", details: "Comprehends stories and explanations"),
        RubricCriterion(name: "Identifies Key Vocabulary", details: "Recognizes important words in context"),
        RubricCriterion(name: "Responds Appropriately", details: "Gives relevant answers to questions")
    ]
    
    let speaking = RubricCategory(name: "Speaking and Oral Production")
    speaking.criteria = [
        RubricCriterion(name: "Clarity and Pronunciation", details: "Speaks clearly and pronounces words correctly"),
        RubricCriterion(name: "Vocabulary Use", details: "Uses appropriate and varied vocabulary"),
        RubricCriterion(name: "Sentence Structure", details: "Forms complete and grammatically correct sentences"),
        RubricCriterion(name: "Participation & Confidence", details: "Actively participates and speaks confidently")
    ]
    
    let reading = RubricCategory(name: "Reading and Comprehension")
    reading.criteria = [
        RubricCriterion(name: "Decoding & Phonics", details: "Applies phonics skills to decode unfamiliar words"),
        RubricCriterion(name: "Reading Fluency & Pace", details: "Reads smoothly and at appropriate speed"),
        RubricCriterion(name: "Understanding Text", details: "Comprehends and interprets reading material"),
        RubricCriterion(name: "Vocabulary Acquisition from Reading", details: "Learns new words through reading")
    ]
    
    let writing = RubricCategory(name: "Writing Skills")
    writing.criteria = [
        RubricCriterion(name: "Legibility & Spelling", details: "Writes neatly and spells words correctly"),
        RubricCriterion(name: "Grammar & Punctuation", details: "Uses proper grammar and punctuation"),
        RubricCriterion(name: "Idea Organization & Expression", details: "Organizes thoughts and expresses ideas clearly"),
        RubricCriterion(name: "Vocabulary in Writing", details: "Uses varied and appropriate vocabulary in writing")
    ]
    
    englishTemplate.categories = [listening, speaking, reading, writing]
    context.insert(englishTemplate)
    
    // General Development
    let generalTemplate = RubricTemplate(
        name: "Primary General Development (Years 1-3)",
        gradeLevel: "Years 1-3",
        subject: "General"
    )
    
    let socialEmotional = RubricCategory(name: "Social-Emotional Development")
    socialEmotional.criteria = [
        RubricCriterion(name: "Works Well with Others", details: "Collaborates effectively and respectfully"),
        RubricCriterion(name: "Manages Emotions Appropriately", details: "Handles frustration and excitement well"),
        RubricCriterion(name: "Shows Respect & Kindness", details: "Treats peers and adults with respect"),
        RubricCriterion(name: "Follows Classroom Rules", details: "Adheres to class expectations")
    ]
    
    let workHabits = RubricCategory(name: "Work Habits")
    workHabits.criteria = [
        RubricCriterion(name: "Completes Tasks on Time", details: "Finishes work within given timeframe"),
        RubricCriterion(name: "Stays Organized", details: "Keeps materials and work area organized"),
        RubricCriterion(name: "Shows Effort & Persistence", details: "Tries hard and doesn't give up easily"),
        RubricCriterion(name: "Asks for Help When Needed", details: "Seeks assistance appropriately")
    ]
    
    generalTemplate.categories = [socialEmotional, workHabits]
    context.insert(generalTemplate)
    
    // Math
    let mathTemplate = RubricTemplate(
        name: "Primary Mathematics (Years 1-3)",
        gradeLevel: "Years 1-3",
        subject: "Math"
    )
    
    let numberSense = RubricCategory(name: "Number Sense")
    numberSense.criteria = [
        RubricCriterion(name: "Counting & Number Recognition", details: "Identifies and counts numbers accurately"),
        RubricCriterion(name: "Basic Operations", details: "Performs addition and subtraction"),
        RubricCriterion(name: "Number Patterns", details: "Recognizes and extends patterns"),
        RubricCriterion(name: "Place Value Understanding", details: "Understands ones, tens, hundreds")
    ]
    
    let problemSolving = RubricCategory(name: "Problem Solving")
    problemSolving.criteria = [
        RubricCriterion(name: "Word Problem Comprehension", details: "Understands what the problem is asking"),
        RubricCriterion(name: "Strategy Selection", details: "Chooses appropriate solving methods"),
        RubricCriterion(name: "Shows Work", details: "Demonstrates thinking process"),
        RubricCriterion(name: "Checks Answers", details: "Verifies solutions make sense")
    ]
    
    mathTemplate.categories = [numberSense, problemSolving]
    context.insert(mathTemplate)
}

// MARK: - INTERMEDIATE (Years 4-6)

func createIntermediateTemplates(context: ModelContext) {
    // English Language
    let englishTemplate = RubricTemplate(
        name: "Intermediate English Language (Years 4-6)",
        gradeLevel: "Years 4-6",
        subject: "English"
    )
    
    let readingAnalysis = RubricCategory(name: "Reading and Analysis")
    readingAnalysis.criteria = [
        RubricCriterion(name: "Comprehension of Complex Texts", details: "Understands multi-layered narratives"),
        RubricCriterion(name: "Inference & Interpretation", details: "Reads between the lines and draws conclusions"),
        RubricCriterion(name: "Literary Elements Recognition", details: "Identifies themes, characters, plot structure"),
        RubricCriterion(name: "Critical Reading", details: "Questions and evaluates what they read")
    ]
    
    let writingComposition = RubricCategory(name: "Writing and Composition")
    writingComposition.criteria = [
        RubricCriterion(name: "Paragraph Structure", details: "Writes well-organized paragraphs with topic sentences"),
        RubricCriterion(name: "Genre Writing", details: "Writes effectively in different formats (narrative, informative, persuasive)"),
        RubricCriterion(name: "Editing & Revision", details: "Reviews and improves own writing"),
        RubricCriterion(name: "Voice & Style", details: "Develops personal writing style")
    ]
    
    let speakingPresentation = RubricCategory(name: "Speaking and Presentation")
    speakingPresentation.criteria = [
        RubricCriterion(name: "Oral Presentation Skills", details: "Presents information clearly and confidently"),
        RubricCriterion(name: "Listening & Responding", details: "Actively listens and responds thoughtfully"),
        RubricCriterion(name: "Discussion Participation", details: "Contributes meaningfully to class discussions"),
        RubricCriterion(name: "Questioning Skills", details: "Asks relevant and thoughtful questions")
    ]
    
    englishTemplate.categories = [readingAnalysis, writingComposition, speakingPresentation]
    context.insert(englishTemplate)
    
    // General Development
    let generalTemplate = RubricTemplate(
        name: "Intermediate General Development (Years 4-6)",
        gradeLevel: "Years 4-6",
        subject: "General"
    )
    
    let criticalThinking = RubricCategory(name: "Critical Thinking")
    criticalThinking.criteria = [
        RubricCriterion(name: "Analyzes Information", details: "Breaks down complex information"),
        RubricCriterion(name: "Makes Connections", details: "Links new learning to prior knowledge"),
        RubricCriterion(name: "Asks Thoughtful Questions", details: "Inquires deeply about topics"),
        RubricCriterion(name: "Evaluates Evidence", details: "Considers quality of information")
    ]
    
    let independence = RubricCategory(name: "Independence & Responsibility")
    independence.criteria = [
        RubricCriterion(name: "Self-Directed Learning", details: "Takes initiative in learning"),
        RubricCriterion(name: "Time Management", details: "Manages time and meets deadlines"),
        RubricCriterion(name: "Organization", details: "Keeps materials and assignments organized"),
        RubricCriterion(name: "Goal Setting", details: "Sets and works toward personal goals")
    ]
    
    let collaboration = RubricCategory(name: "Collaboration")
    collaboration.criteria = [
        RubricCriterion(name: "Teamwork", details: "Works effectively in groups"),
        RubricCriterion(name: "Communication", details: "Expresses ideas clearly to peers"),
        RubricCriterion(name: "Conflict Resolution", details: "Resolves disagreements constructively"),
        RubricCriterion(name: "Leadership", details: "Takes appropriate leadership roles")
    ]
    
    generalTemplate.categories = [criticalThinking, independence, collaboration]
    context.insert(generalTemplate)
    
    // Math
    let mathTemplate = RubricTemplate(
        name: "Intermediate Mathematics (Years 4-6)",
        gradeLevel: "Years 4-6",
        subject: "Math"
    )
    
    let numericalSkills = RubricCategory(name: "Numerical Skills")
    numericalSkills.criteria = [
        RubricCriterion(name: "Multi-digit Operations", details: "Performs complex calculations accurately"),
        RubricCriterion(name: "Fractions & Decimals", details: "Understands and works with rational numbers"),
        RubricCriterion(name: "Mental Math", details: "Calculates efficiently without paper"),
        RubricCriterion(name: "Estimation", details: "Makes reasonable approximations")
    ]
    
    let mathematicalThinking = RubricCategory(name: "Mathematical Thinking")
    mathematicalThinking.criteria = [
        RubricCriterion(name: "Problem Solving Strategies", details: "Uses multiple approaches to solve problems"),
        RubricCriterion(name: "Logical Reasoning", details: "Explains mathematical thinking clearly"),
        RubricCriterion(name: "Pattern Recognition", details: "Identifies and uses mathematical patterns"),
        RubricCriterion(name: "Real-World Application", details: "Applies math to practical situations")
    ]
    
    mathTemplate.categories = [numericalSkills, mathematicalThinking]
    context.insert(mathTemplate)
}

// MARK: - SECONDARY (Years 7-9)

func createSecondaryTemplates(context: ModelContext) {
    // English/Language Arts
    let englishTemplate = RubricTemplate(
        name: "Secondary English Language Arts (Years 7-9)",
        gradeLevel: "Years 7-9",
        subject: "English"
    )
    
    let literaryAnalysis = RubricCategory(name: "Literary Analysis")
    literaryAnalysis.criteria = [
        RubricCriterion(name: "Textual Analysis", details: "Analyzes themes, symbolism, and literary devices"),
        RubricCriterion(name: "Character & Plot Analysis", details: "Examines character development and narrative structure"),
        RubricCriterion(name: "Historical & Cultural Context", details: "Considers texts within broader contexts"),
        RubricCriterion(name: "Comparative Analysis", details: "Compares and contrasts multiple texts")
    ]
    
    let academicWriting = RubricCategory(name: "Academic Writing")
    academicWriting.criteria = [
        RubricCriterion(name: "Thesis Development", details: "Creates clear, arguable thesis statements"),
        RubricCriterion(name: "Evidence & Citations", details: "Supports claims with textual evidence"),
        RubricCriterion(name: "Essay Organization", details: "Structures multi-paragraph essays effectively"),
        RubricCriterion(name: "Academic Voice", details: "Maintains formal, objective tone")
    ]
    
    let research = RubricCategory(name: "Research Skills")
    research.criteria = [
        RubricCriterion(name: "Source Evaluation", details: "Assesses credibility of sources"),
        RubricCriterion(name: "Note-Taking", details: "Records information effectively"),
        RubricCriterion(name: "Synthesis", details: "Combines information from multiple sources"),
        RubricCriterion(name: "Documentation", details: "Cites sources properly")
    ]
    
    englishTemplate.categories = [literaryAnalysis, academicWriting, research]
    context.insert(englishTemplate)
    
    // General Development
    let generalTemplate = RubricTemplate(
        name: "Secondary General Development (Years 7-9)",
        gradeLevel: "Years 7-9",
        subject: "General"
    )
    
    let academicSkills = RubricCategory(name: "Academic Skills")
    academicSkills.criteria = [
        RubricCriterion(name: "Study Skills", details: "Uses effective study strategies"),
        RubricCriterion(name: "Note-Taking", details: "Takes organized, comprehensive notes"),
        RubricCriterion(name: "Test Preparation", details: "Prepares thoroughly for assessments"),
        RubricCriterion(name: "Academic Integrity", details: "Maintains honesty in all work")
    ]
    
    let digitalLiteracy = RubricCategory(name: "Digital Literacy")
    digitalLiteracy.criteria = [
        RubricCriterion(name: "Technology Use", details: "Uses technology effectively for learning"),
        RubricCriterion(name: "Online Research", details: "Conducts effective internet research"),
        RubricCriterion(name: "Digital Citizenship", details: "Acts responsibly online"),
        RubricCriterion(name: "Media Literacy", details: "Critically evaluates digital media")
    ]
    
    let problemSolving = RubricCategory(name: "Problem-Solving & Creativity")
    problemSolving.criteria = [
        RubricCriterion(name: "Creative Thinking", details: "Generates original ideas and solutions"),
        RubricCriterion(name: "Critical Analysis", details: "Evaluates problems from multiple angles"),
        RubricCriterion(name: "Persistence", details: "Perseveres through challenging tasks"),
        RubricCriterion(name: "Innovation", details: "Applies creative solutions to problems")
    ]
    
    generalTemplate.categories = [academicSkills, digitalLiteracy, problemSolving]
    context.insert(generalTemplate)
    
    // Math
    let mathTemplate = RubricTemplate(
        name: "Secondary Mathematics (Years 7-9)",
        gradeLevel: "Years 7-9",
        subject: "Math"
    )
    
    let algebraicThinking = RubricCategory(name: "Algebraic Thinking")
    algebraicThinking.criteria = [
        RubricCriterion(name: "Variables & Expressions", details: "Works with algebraic expressions"),
        RubricCriterion(name: "Equation Solving", details: "Solves linear equations"),
        RubricCriterion(name: "Graphing", details: "Represents relationships graphically"),
        RubricCriterion(name: "Functions", details: "Understands function concepts")
    ]
    
    let geometricReasoning = RubricCategory(name: "Geometric Reasoning")
    geometricReasoning.criteria = [
        RubricCriterion(name: "Spatial Visualization", details: "Visualizes and manipulates shapes"),
        RubricCriterion(name: "Measurement", details: "Calculates area, volume, etc."),
        RubricCriterion(name: "Geometric Proofs", details: "Constructs logical geometric arguments"),
        RubricCriterion(name: "Transformations", details: "Understands translations, rotations, reflections")
    ]
    
    mathTemplate.categories = [algebraicThinking, geometricReasoning]
    context.insert(mathTemplate)
}

// MARK: - HIGH SCHOOL (Years 10-12)

func createHighSchoolTemplates(context: ModelContext) {
    // English/Language Arts
    let englishTemplate = RubricTemplate(
        name: "High School English Language Arts (Years 10-12)",
        gradeLevel: "Years 10-12",
        subject: "English"
    )
    
    let advancedAnalysis = RubricCategory(name: "Advanced Literary Analysis")
    advancedAnalysis.criteria = [
        RubricCriterion(name: "Complex Textual Analysis", details: "Analyzes sophisticated literary works"),
        RubricCriterion(name: "Critical Theory Application", details: "Applies literary criticism frameworks"),
        RubricCriterion(name: "Intertextual Connections", details: "Makes connections across texts and media"),
        RubricCriterion(name: "Independent Interpretation", details: "Develops original analytical perspectives")
    ]
    
    let collegeWriting = RubricCategory(name: "College-Level Writing")
    collegeWriting.criteria = [
        RubricCriterion(name: "Argumentative Writing", details: "Constructs sophisticated arguments"),
        RubricCriterion(name: "Research Papers", details: "Produces formal research papers"),
        RubricCriterion(name: "Rhetorical Analysis", details: "Analyzes rhetorical strategies"),
        RubricCriterion(name: "Style & Sophistication", details: "Demonstrates mature writing style")
    ]
    
    let oralCommunication = RubricCategory(name: "Advanced Communication")
    oralCommunication.criteria = [
        RubricCriterion(name: "Formal Presentations", details: "Delivers polished presentations"),
        RubricCriterion(name: "Debate & Discussion", details: "Engages in academic discourse"),
        RubricCriterion(name: "Synthesis", details: "Integrates multiple perspectives"),
        RubricCriterion(name: "Professional Communication", details: "Communicates in professional contexts")
    ]
    
    englishTemplate.categories = [advancedAnalysis, collegeWriting, oralCommunication]
    context.insert(englishTemplate)
    
    // General Development
    let generalTemplate = RubricTemplate(
        name: "High School College/Career Readiness (Years 10-12)",
        gradeLevel: "Years 10-12",
        subject: "General"
    )
    
    let collegeReadiness = RubricCategory(name: "College/Career Readiness")
    collegeReadiness.criteria = [
        RubricCriterion(name: "Academic Independence", details: "Works independently at college level"),
        RubricCriterion(name: "Time Management", details: "Manages complex schedules and deadlines"),
        RubricCriterion(name: "Long-Term Planning", details: "Plans and executes extended projects"),
        RubricCriterion(name: "Professional Skills", details: "Demonstrates workplace-ready skills")
    ]
    
    let leadership = RubricCategory(name: "Leadership & Initiative")
    leadership.criteria = [
        RubricCriterion(name: "Leadership Roles", details: "Takes leadership in groups and activities"),
        RubricCriterion(name: "Initiative", details: "Self-starts learning and projects"),
        RubricCriterion(name: "Mentoring", details: "Supports and guides peers"),
        RubricCriterion(name: "Community Engagement", details: "Contributes to broader community")
    ]
    
    let selfManagement = RubricCategory(name: "Self-Management")
    selfManagement.criteria = [
        RubricCriterion(name: "Goal Setting & Achievement", details: "Sets and achieves ambitious goals"),
        RubricCriterion(name: "Stress Management", details: "Handles academic pressure effectively"),
        RubricCriterion(name: "Self-Reflection", details: "Reflects on strengths and areas for growth"),
        RubricCriterion(name: "Resilience", details: "Bounces back from setbacks")
    ]
    
    let globalAwareness = RubricCategory(name: "Global Awareness")
    globalAwareness.criteria = [
        RubricCriterion(name: "Cultural Awareness", details: "Understands diverse perspectives"),
        RubricCriterion(name: "Social Responsibility", details: "Acts as responsible global citizen"),
        RubricCriterion(name: "Ethical Reasoning", details: "Considers ethical implications"),
        RubricCriterion(name: "Current Events Knowledge", details: "Stays informed about world issues")
    ]
    
    generalTemplate.categories = [collegeReadiness, leadership, selfManagement, globalAwareness]
    context.insert(generalTemplate)
    
    // Math
    let mathTemplate = RubricTemplate(
        name: "High School Mathematics (Years 10-12)",
        gradeLevel: "Years 10-12",
        subject: "Math"
    )
    
    let advancedAlgebra = RubricCategory(name: "Advanced Algebra & Functions")
    advancedAlgebra.criteria = [
        RubricCriterion(name: "Complex Functions", details: "Works with polynomial, exponential, logarithmic functions"),
        RubricCriterion(name: "Systems of Equations", details: "Solves complex equation systems"),
        RubricCriterion(name: "Mathematical Modeling", details: "Creates mathematical models of real situations"),
        RubricCriterion(name: "Abstract Reasoning", details: "Thinks abstractly about mathematical concepts")
    ]
    
    let calculusReadiness = RubricCategory(name: "Calculus & Advanced Topics")
    calculusReadiness.criteria = [
        RubricCriterion(name: "Limits & Continuity", details: "Understands limit concepts"),
        RubricCriterion(name: "Rates of Change", details: "Analyzes changing quantities"),
        RubricCriterion(name: "Integration", details: "Understands accumulation"),
        RubricCriterion(name: "Mathematical Proof", details: "Constructs rigorous mathematical arguments")
    ]
    
    mathTemplate.categories = [advancedAlgebra, calculusReadiness]
    context.insert(mathTemplate)
}
