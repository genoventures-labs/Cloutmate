//
//  AuroraToneKit.swift
//  Cloutmate
//
//  Modular tone system for unified emotion mapping across the app
//  Includes TTS-optimized voice characteristics for Ollama speech synthesis
//

import SwiftUI
import CloutmateShared

/// Emotional micro-tones for different contexts
enum AuroraTone: String, CaseIterable {
    // Ritual tones
    case clarityCharge = "Clarity & Charge"
    case releaseReview = "Release & Review"
    
    // Focus & Work tones
    case deepFocus = "Deep Focus"
    case creativeFlow = "Creative Flow"
    case productiveMomentum = "Productive Momentum"
    case analytical = "Analytical"
    
    // Emotional & Reflective tones
    case reflective = "Reflective"
    case contemplative = "Contemplative"
    case supportive = "Supportive"
    case celebratory = "Celebratory"
    
    // Guidance tones
    case gentleGuidance = "Gentle Guidance"
    case confidentDirection = "Confident Direction"
    case encouraging = "Encouraging"
    case reassuring = "Reassuring"
    
    // Insight tones
    case insightful = "Insightful"
    case analyticalInsight = "Analytical Insight"
    case patternRecognition = "Pattern Recognition"
    
    // Error & Problem tones
    case gentleError = "Gentle Error"
    case constructiveFeedback = "Constructive Feedback"
    case problemSolving = "Problem Solving"
    case troubleshooting = "Troubleshooting"
    
    // Learning & Educational tones
    case educational = "Educational"
    case tutorial = "Tutorial"
    case discovery = "Discovery"
    case exploratory = "Exploratory"
    
    // Social & Communication tones
    case collaborative = "Collaborative"
    case conversational = "Conversational"
    case empathetic = "Empathetic"
    case diplomatic = "Diplomatic"
    
    // Health & Wellness tones
    case restorative = "Restorative"
    case mindful = "Mindful"
    case recovery = "Recovery"
    case rejuvenating = "Rejuvenating"
    
    // Achievement & Milestone tones
    case milestone = "Milestone"
    case breakthrough = "Breakthrough"
    case progress = "Progress"
    case accomplishment = "Accomplishment"
    
    // Warning & Alert tones
    case alert = "Alert"
    case caution = "Caution"
    case gentleWarning = "Gentle Warning"
    case importantNotice = "Important Notice"
    
    // Transition & Change tones
    case smoothTransition = "Smooth Transition"
    case phaseShift = "Phase Shift"
    case adaptation = "Adaptation"
    case transformation = "Transformation"
    
    // Time-based tones
    case morningVibes = "Morning Vibes"
    case afternoonEnergy = "Afternoon Energy"
    case eveningCalm = "Evening Calm"
    case nightReflection = "Night Reflection"
    
    // Workload & Context tones
    case lightLoad = "Light Load"
    case heavyLoad = "Heavy Load"
    case balanced = "Balanced"
    case overloaded = "Overloaded"
    
    // Recovery & Reset tones
    case rest = "Rest"
    case recharge = "Recharge"
    case reset = "Reset"
    case pause = "Pause"
    
    var displayName: String {
        rawValue
    }
    
    var description: String {
        switch self {
        case .clarityCharge:
            return "Energetic, forward-looking, intentional"
        case .releaseReview:
            return "Reflective, calming, gentle"
        case .deepFocus:
            return "Concentrated, immersive, sustained"
        case .creativeFlow:
            return "Expressive, exploratory, fluid"
        case .productiveMomentum:
            return "Dynamic, forward-moving, efficient"
        case .analytical:
            return "Precise, methodical, data-driven"
        case .reflective:
            return "Thoughtful, introspective, contemplative"
        case .contemplative:
            return "Deep, meditative, philosophical"
        case .supportive:
            return "Warm, understanding, empathetic"
        case .celebratory:
            return "Joyful, uplifting, positive"
        case .gentleGuidance:
            return "Soft, patient, nurturing"
        case .confidentDirection:
            return "Clear, decisive, authoritative"
        case .encouraging:
            return "Motivational, uplifting, positive"
        case .reassuring:
            return "Calming, comforting, stable"
        case .insightful:
            return "Perceptive, wise, illuminating"
        case .analyticalInsight:
            return "Data-driven, logical, revealing"
        case .patternRecognition:
            return "Observant, connecting, synthesizing"
        
        @unknown default:
            return rawValue
        }
    }
}

/// Reusable tone system for unified emotion mapping
struct AuroraToneKit {
    /// Get tone for a ritual type
    static func tone(for ritualType: FocusRitualType) -> AuroraTone {
        switch ritualType {
        case .morning:
            return .clarityCharge
        case .evening:
            return .releaseReview
        }
    }
    
    /// Get display name for a tone
    static func displayName(for tone: AuroraTone) -> String {
        tone.displayName
    }
    
    /// Get accent color for a tone
    static func accentColor(for tone: AuroraTone) -> Color {
        switch tone {
        // Ritual tones
        case .clarityCharge:
            return .kosmicBlue
        case .releaseReview:
            return .kosmicPurple
        
        // Focus & Work tones
        case .deepFocus:
            return .kosmicBlue
        case .creativeFlow:
            return .kosmicPurple
        case .productiveMomentum:
            return .kosmicGreen
        case .analytical:
            return .kosmicCyan
        
        // Emotional & Reflective tones
        case .reflective:
            return .kosmicPurple
        case .contemplative:
            return .kosmicBlue.opacity(0.8)
        case .supportive:
            return .kosmicGreen.opacity(0.9)
        case .celebratory:
            return .orange
        
        // Guidance tones
        case .gentleGuidance:
            return .kosmicPurple.opacity(0.7)
        case .confidentDirection:
            return .kosmicBlue
        case .encouraging:
            return .kosmicGreen
        case .reassuring:
            return .kosmicBlue.opacity(0.8)
        
        // Insight tones
        case .insightful:
            return .kosmicPurple
        case .analyticalInsight:
            return .kosmicCyan
        case .patternRecognition:
            return .kosmicPurple.opacity(0.85)
        
        // Error & Problem tones
        case .gentleError:
            return .orange.opacity(0.7)
        case .constructiveFeedback:
            return .kosmicBlue.opacity(0.8)
        case .problemSolving:
            return .kosmicCyan
        case .troubleshooting:
            return .kosmicBlue
        
        // Learning & Educational tones
        case .educational:
            return .kosmicGreen
        case .tutorial:
            return .kosmicBlue
        case .discovery:
            return .kosmicPurple
        case .exploratory:
            return .kosmicPurple.opacity(0.85)
        
        // Social & Communication tones
        case .collaborative:
            return .kosmicGreen.opacity(0.9)
        case .conversational:
            return .kosmicBlue.opacity(0.8)
        case .empathetic:
            return .kosmicPurple.opacity(0.75)
        case .diplomatic:
            return .kosmicBlue.opacity(0.85)
        
        // Health & Wellness tones
        case .restorative:
            return .kosmicGreen.opacity(0.7)
        case .mindful:
            return .kosmicBlue.opacity(0.75)
        case .recovery:
            return .kosmicPurple.opacity(0.7)
        case .rejuvenating:
            return .kosmicGreen
        
        // Achievement & Milestone tones
        case .milestone:
            return .orange
        case .breakthrough:
            return .kosmicGreen
        case .progress:
            return .kosmicBlue
        case .accomplishment:
            return .kosmicGreen.opacity(0.9)
        
        // Warning & Alert tones
        case .alert:
            return .orange
        case .caution:
            return .orange.opacity(0.8)
        case .gentleWarning:
            return .orange.opacity(0.6)
        case .importantNotice:
            return .kosmicBlue
        
        // Transition & Change tones
        case .smoothTransition:
            return .kosmicPurple.opacity(0.8)
        case .phaseShift:
            return .kosmicBlue
        case .adaptation:
            return .kosmicGreen.opacity(0.85)
        case .transformation:
            return .kosmicPurple
        
        // Time-based tones
        case .morningVibes:
            return .kosmicBlue
        case .afternoonEnergy:
            return .kosmicGreen
        case .eveningCalm:
            return .kosmicPurple.opacity(0.75)
        case .nightReflection:
            return .kosmicPurple.opacity(0.65)
        
        // Workload & Context tones
        case .lightLoad:
            return .kosmicGreen.opacity(0.7)
        case .heavyLoad:
            return .orange.opacity(0.8)
        case .balanced:
            return .kosmicBlue.opacity(0.8)
        case .overloaded:
            return .orange
        
        // Recovery & Reset tones
        case .rest:
            return .kosmicPurple.opacity(0.65)
        case .recharge:
            return .kosmicGreen.opacity(0.8)
        case .reset:
            return .kosmicBlue.opacity(0.75)
        case .pause:
            return .kosmicPurple.opacity(0.7)
        }
    }
    
    /// Get accent gradient for a tone
    static func accentGradient(for tone: AuroraTone) -> LinearGradient {
        switch tone {
        // Ritual tones
        case .clarityCharge:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .releaseReview:
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Focus & Work tones
        case .deepFocus:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .creativeFlow:
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .productiveMomentum:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .analytical:
            return LinearGradient(
                colors: [.kosmicCyan, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Emotional & Reflective tones
        case .reflective:
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .contemplative:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.8), .kosmicPurple.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .supportive:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .celebratory:
            return LinearGradient(
                colors: [.orange, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Guidance tones
        case .gentleGuidance:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.7), .kosmicBlue.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .confidentDirection:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicCyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .encouraging:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .reassuring:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.8), .kosmicPurple.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        
        // Insight tones
        case .insightful:
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .analyticalInsight:
            return LinearGradient(
                colors: [.kosmicCyan, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .patternRecognition:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.85), .kosmicBlue.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Error & Problem tones
        case .gentleError:
            return LinearGradient(
                colors: [.orange.opacity(0.7), .kosmicPurple.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .constructiveFeedback:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicCyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .problemSolving:
            return LinearGradient(
                colors: [.kosmicCyan, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .troubleshooting:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicPurple],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Learning & Educational tones
        case .educational:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .tutorial:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicCyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .discovery:
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .exploratory:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.85), .kosmicBlue.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Social & Communication tones
        case .collaborative:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .conversational:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.8), .kosmicPurple.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .empathetic:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.75), .kosmicGreen.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .diplomatic:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.85), .kosmicPurple.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Health & Wellness tones
        case .restorative:
            return LinearGradient(
                colors: [.kosmicGreen.opacity(0.7), .kosmicBlue.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .mindful:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.75), .kosmicPurple.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .recovery:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.7), .kosmicGreen.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .rejuvenating:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Achievement & Milestone tones
        case .milestone:
            return LinearGradient(
                colors: [.orange, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .breakthrough:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicPurple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .progress:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .accomplishment:
            return LinearGradient(
                colors: [.kosmicGreen.opacity(0.9), .kosmicBlue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Warning & Alert tones
        case .alert:
            return LinearGradient(
                colors: [.orange, .red.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .caution:
            return LinearGradient(
                colors: [.orange.opacity(0.8), .orange.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .gentleWarning:
            return LinearGradient(
                colors: [.orange.opacity(0.6), .kosmicPurple.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .importantNotice:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicCyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Transition & Change tones
        case .smoothTransition:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.8), .kosmicBlue.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .phaseShift:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicPurple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .adaptation:
            return LinearGradient(
                colors: [.kosmicGreen.opacity(0.85), .kosmicBlue.opacity(0.75)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .transformation:
            return LinearGradient(
                colors: [.kosmicPurple, .kosmicGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Time-based tones
        case .morningVibes:
            return LinearGradient(
                colors: [.kosmicBlue, .kosmicGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .afternoonEnergy:
            return LinearGradient(
                colors: [.kosmicGreen, .kosmicBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .eveningCalm:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.75), .kosmicBlue.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .nightReflection:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.65), .kosmicBlue.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        
        // Workload & Context tones
        case .lightLoad:
            return LinearGradient(
                colors: [.kosmicGreen.opacity(0.7), .kosmicBlue.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .heavyLoad:
            return LinearGradient(
                colors: [.orange.opacity(0.8), .orange.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .balanced:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.8), .kosmicPurple.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .overloaded:
            return LinearGradient(
                colors: [.orange, .red.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        
        // Recovery & Reset tones
        case .rest:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.65), .kosmicBlue.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .recharge:
            return LinearGradient(
                colors: [.kosmicGreen.opacity(0.8), .kosmicBlue.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .reset:
            return LinearGradient(
                colors: [.kosmicBlue.opacity(0.75), .kosmicPurple.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .pause:
            return LinearGradient(
                colors: [.kosmicPurple.opacity(0.7), .kosmicBlue.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    /// Get opacity for a tone (affects visual intensity)
    static func opacity(for tone: AuroraTone) -> Double {
        switch tone {
        // Ritual tones
        case .clarityCharge:
            return 0.9 // Higher opacity for vibrant, energetic feel
        case .releaseReview:
            return 0.75 // Lower opacity for softer, calming feel
        
        // Focus & Work tones
        case .deepFocus:
            return 0.85
        case .creativeFlow:
            return 0.8
        case .productiveMomentum:
            return 0.88
        case .analytical:
            return 0.82
        
        // Emotional & Reflective tones
        case .reflective:
            return 0.7
        case .contemplative:
            return 0.65
        case .supportive:
            return 0.78
        case .celebratory:
            return 0.92
        
        // Guidance tones
        case .gentleGuidance:
            return 0.72
        case .confidentDirection:
            return 0.86
        case .encouraging:
            return 0.84
        case .reassuring:
            return 0.74
        
        // Insight tones
        case .insightful:
            return 0.8
        case .analyticalInsight:
            return 0.83
        case .patternRecognition:
            return 0.81
        
        // Error & Problem tones
        case .gentleError:
            return 0.68
        case .constructiveFeedback:
            return 0.79
        case .problemSolving:
            return 0.84
        case .troubleshooting:
            return 0.83
        
        // Learning & Educational tones
        case .educational:
            return 0.81
        case .tutorial:
            return 0.78
        case .discovery:
            return 0.77
        case .exploratory:
            return 0.76
        
        // Social & Communication tones
        case .collaborative:
            return 0.82
        case .conversational:
            return 0.75
        case .empathetic:
            return 0.73
        case .diplomatic:
            return 0.77
        
        // Health & Wellness tones
        case .restorative:
            return 0.66
        case .mindful:
            return 0.69
        case .recovery:
            return 0.67
        case .rejuvenating:
            return 0.8
        
        // Achievement & Milestone tones
        case .milestone:
            return 0.89
        case .breakthrough:
            return 0.91
        case .progress:
            return 0.85
        case .accomplishment:
            return 0.88
        
        // Warning & Alert tones
        case .alert:
            return 0.93
        case .caution:
            return 0.87
        case .gentleWarning:
            return 0.71
        case .importantNotice:
            return 0.86
        
        // Transition & Change tones
        case .smoothTransition:
            return 0.76
        case .phaseShift:
            return 0.84
        case .adaptation:
            return 0.8
        case .transformation:
            return 0.87
        
        // Time-based tones
        case .morningVibes:
            return 0.88
        case .afternoonEnergy:
            return 0.86
        case .eveningCalm:
            return 0.72
        case .nightReflection:
            return 0.68
        
        // Workload & Context tones
        case .lightLoad:
            return 0.74
        case .heavyLoad:
            return 0.9
        case .balanced:
            return 0.78
        case .overloaded:
            return 0.92
        
        // Recovery & Reset tones
        case .rest:
            return 0.64
        case .recharge:
            return 0.79
        case .reset:
            return 0.76
        case .pause:
            return 0.7
        }
    }
    
    /// Get prompt prefix for AI summaries (e.g., "Let's start strong")
    static func promptPrefix(for tone: AuroraTone) -> String {
        switch tone {
        // Ritual tones
        case .clarityCharge:
            return "Let's start strong"
        case .releaseReview:
            return "Let's wind down"
        
        // Focus & Work tones
        case .deepFocus:
            return "Let's dive deep"
        case .creativeFlow:
            return "Let's flow"
        case .productiveMomentum:
            return "Let's keep moving"
        case .analytical:
            return "Let's analyze"
        
        // Emotional & Reflective tones
        case .reflective:
            return "Let's reflect"
        case .contemplative:
            return "Let's contemplate"
        case .supportive:
            return "I'm here with you"
        case .celebratory:
            return "Let's celebrate"
        
        // Guidance tones
        case .gentleGuidance:
            return "Here's a gentle suggestion"
        case .confidentDirection:
            return "Here's what I recommend"
        case .encouraging:
            return "You've got this"
        case .reassuring:
            return "Everything's okay"
        
        // Insight tones
        case .insightful:
            return "Here's what I notice"
        case .analyticalInsight:
            return "The data shows"
        case .patternRecognition:
            return "I'm seeing a pattern"
        
        // Error & Problem tones
        case .gentleError:
            return "Let's fix this together"
        case .constructiveFeedback:
            return "Here's what I noticed"
        case .problemSolving:
            return "Let's work through this"
        case .troubleshooting:
            return "Let's diagnose this"
        
        // Learning & Educational tones
        case .educational:
            return "Here's what you should know"
        case .tutorial:
            return "Let me walk you through"
        case .discovery:
            return "Here's something interesting"
        case .exploratory:
            return "Let's explore"
        
        // Social & Communication tones
        case .collaborative:
            return "Let's work together"
        case .conversational:
            return "Here's what I'm thinking"
        case .empathetic:
            return "I understand"
        case .diplomatic:
            return "Let's consider"
        
        // Health & Wellness tones
        case .restorative:
            return "Let's restore"
        case .mindful:
            return "Let's be present"
        case .recovery:
            return "Let's recover"
        case .rejuvenating:
            return "Let's refresh"
        
        // Achievement & Milestone tones
        case .milestone:
            return "Congratulations"
        case .breakthrough:
            return "You did it"
        case .progress:
            return "You're making progress"
        case .accomplishment:
            return "Well done"
        
        // Warning & Alert tones
        case .alert:
            return "Important"
        case .caution:
            return "Heads up"
        case .gentleWarning:
            return "Just so you know"
        case .importantNotice:
            return "Note"
        
        // Transition & Change tones
        case .smoothTransition:
            return "Moving forward"
        case .phaseShift:
            return "New phase"
        case .adaptation:
            return "Adapting"
        case .transformation:
            return "Transforming"
        
        // Time-based tones
        case .morningVibes:
            return "Good morning"
        case .afternoonEnergy:
            return "Afternoon"
        case .eveningCalm:
            return "Evening"
        case .nightReflection:
            return "Late night"
        
        // Workload & Context tones
        case .lightLoad:
            return "You've got space"
        case .heavyLoad:
            return "You're carrying a lot"
        case .balanced:
            return "You're in balance"
        case .overloaded:
            return "You're overloaded"
        
        // Recovery & Reset tones
        case .rest:
            return "Time to rest"
        case .recharge:
            return "Time to recharge"
        case .reset:
            return "Let's reset"
        case .pause:
            return "Let's pause"
        }
    }
    
    /// Get tone description for AI prompts
    static func summaryTone(for tone: AuroraTone) -> String {
        switch tone {
        // Ritual tones
        case .clarityCharge:
            return "energetic, charge-focused, forward-looking and motivational"
        case .releaseReview:
            return "release-focused, review-oriented, reflective and calming"
        
        // Focus & Work tones
        case .deepFocus:
            return "concentrated, immersive, sustained and intentional"
        case .creativeFlow:
            return "expressive, exploratory, fluid and open"
        case .productiveMomentum:
            return "dynamic, forward-moving, efficient and goal-oriented"
        case .analytical:
            return "precise, methodical, data-driven and logical"
        
        // Emotional & Reflective tones
        case .reflective:
            return "thoughtful, introspective, contemplative and gentle"
        case .contemplative:
            return "deep, meditative, philosophical and introspective"
        case .supportive:
            return "warm, understanding, empathetic and caring"
        case .celebratory:
            return "joyful, uplifting, positive and enthusiastic"
        
        // Guidance tones
        case .gentleGuidance:
            return "soft, patient, nurturing and understanding"
        case .confidentDirection:
            return "clear, decisive, authoritative and trustworthy"
        case .encouraging:
            return "motivational, uplifting, positive and inspiring"
        case .reassuring:
            return "calming, comforting, stable and supportive"
        
        // Insight tones
        case .insightful:
            return "perceptive, wise, illuminating and thoughtful"
        case .analyticalInsight:
            return "data-driven, logical, revealing and precise"
        case .patternRecognition:
            return "observant, connecting, synthesizing and pattern-aware"
        
        // Error & Problem tones
        case .gentleError:
            return "soft, understanding, solution-oriented and non-judgmental"
        case .constructiveFeedback:
            return "helpful, specific, actionable and growth-focused"
        case .problemSolving:
            return "methodical, logical, step-by-step and solution-driven"
        case .troubleshooting:
            return "systematic, diagnostic, patient and thorough"
        
        // Learning & Educational tones
        case .educational:
            return "clear, structured, informative and accessible"
        case .tutorial:
            return "step-by-step, patient, encouraging and detailed"
        case .discovery:
            return "curious, open, exploratory and wonder-filled"
        case .exploratory:
            return "adventurous, open-minded, experimental and flexible"
        
        // Social & Communication tones
        case .collaborative:
            return "inclusive, cooperative, team-oriented and supportive"
        case .conversational:
            return "natural, friendly, approachable and engaging"
        case .empathetic:
            return "understanding, compassionate, validating and caring"
        case .diplomatic:
            return "balanced, respectful, considerate and tactful"
        
        // Health & Wellness tones
        case .restorative:
            return "healing, nurturing, gentle and renewing"
        case .mindful:
            return "present, aware, calm and centered"
        case .recovery:
            return "supportive, patient, gradual and healing"
        case .rejuvenating:
            return "refreshing, energizing, revitalizing and uplifting"
        
        // Achievement & Milestone tones
        case .milestone:
            return "acknowledging, proud, significant and meaningful"
        case .breakthrough:
            return "exciting, transformative, significant and empowering"
        case .progress:
            return "positive, forward-moving, incremental and encouraging"
        case .accomplishment:
            return "proud, validating, rewarding and satisfying"
        
        // Warning & Alert tones
        case .alert:
            return "urgent, clear, attention-grabbing and important"
        case .caution:
            return "careful, measured, aware and prudent"
        case .gentleWarning:
            return "soft, caring, protective and considerate"
        case .importantNotice:
            return "clear, significant, noteworthy and informative"
        
        // Transition & Change tones
        case .smoothTransition:
            return "seamless, natural, flowing and effortless"
        case .phaseShift:
            return "transformative, significant, marked and clear"
        case .adaptation:
            return "flexible, responsive, adjusting and resilient"
        case .transformation:
            return "profound, meaningful, complete and evolved"
        
        // Time-based tones
        case .morningVibes:
            return "fresh, energetic, optimistic and new"
        case .afternoonEnergy:
            return "active, productive, engaged and dynamic"
        case .eveningCalm:
            return "relaxed, peaceful, winding down and gentle"
        case .nightReflection:
            return "quiet, introspective, contemplative and restful"
        
        // Workload & Context tones
        case .lightLoad:
            return "manageable, comfortable, relaxed and easy"
        case .heavyLoad:
            return "intense, demanding, challenging and significant"
        case .balanced:
            return "equilibrium, stable, harmonious and sustainable"
        case .overloaded:
            return "overwhelming, excessive, urgent and needing relief"
        
        // Recovery & Reset tones
        case .rest:
            return "peaceful, restorative, quiet and rejuvenating"
        case .recharge:
            return "energizing, refreshing, renewing and revitalizing"
        case .reset:
            return "fresh start, clean slate, new beginning and clear"
        case .pause:
            return "temporary stop, reflection, break and consideration"
        }
    }
    
    // MARK: - Context-Specific Tone Getters
    
    /// Get tone for a journal entry based on mood and type
    static func tone(for journalMood: JournalMood, entryType: JournalEntryType) -> AuroraTone {
        switch journalMood {
        case .excited, .motivated:
            return .celebratory
        case .grateful:
            return .supportive
        case .reflective, .contemplative:
            return entryType == .reflection ? .reflective : .contemplative
        case .creative:
            return .creativeFlow
        case .frustrated:
            return .reassuring
        case .calm:
            return .gentleGuidance
        case .none:
            return entryType == .reflection ? .reflective : .insightful
        }
    }
    
    /// Get tone for Focus Mode based on session type
    static func tone(for focusMode: String) -> AuroraTone {
        let mode = focusMode.lowercased()
        if mode.contains("deep") || mode.contains("concentrated") {
            return .deepFocus
        } else if mode.contains("creative") || mode.contains("flow") {
            return .creativeFlow
        } else if mode.contains("analytical") || mode.contains("analysis") {
            return .analytical
        } else {
            return .productiveMomentum
        }
    }
    
    /// Get tone for Insights view based on view type
    static func tone(forInsightsViewType insightsViewType: String) -> AuroraTone {
        let type = insightsViewType.lowercased()
        if type.contains("pattern") || type.contains("behavior") {
            return .patternRecognition
        } else if type.contains("analytics") || type.contains("data") {
            return .analyticalInsight
        } else if type.contains("emotion") || type.contains("mood") {
            return .reflective
        } else {
            return .insightful
        }
    }
    
    /// Get tone for Emotional State (ARTE)
    static func tone(for emotionalState: EmotionalState) -> AuroraTone {
        switch emotionalState {
        case .focused:
            return .deepFocus
        case .reflective:
            return .reflective
        case .calm:
            return .gentleGuidance
        case .energized:
            return .productiveMomentum
        case .fatigued:
            return .rest
        }
    }
    
    /// Get tone for time of day
    static func tone(for timeOfDay: TimeOfDayContext) -> AuroraTone {
        switch timeOfDay {
        case .morning:
            return .morningVibes
        case .lateMorning:
            return .clarityCharge
        case .midday:
            return .afternoonEnergy
        case .afternoon:
            return .afternoonEnergy
        case .evening:
            return .eveningCalm
        case .night:
            return .nightReflection
        }
    }
    
    /// Get tone for workload level
    static func tone(for workloadLevel: WorkloadLevel) -> AuroraTone {
        switch workloadLevel {
        case .light:
            return .lightLoad
        case .moderate:
            return .balanced
        case .heavy:
            return .heavyLoad
        case .overloaded:
            return .overloaded
        }
    }
    
    /// Get tone for error/issue severity
    static func tone(for errorSeverity: ErrorSeverity) -> AuroraTone {
        switch errorSeverity {
        case .info:
            return .importantNotice
        case .warning:
            return .gentleWarning
        case .error:
            return .gentleError
        case .critical:
            return .alert
        }
    }
    
    /// Get tone for achievement type
    static func tone(for achievementType: AchievementType) -> AuroraTone {
        switch achievementType {
        case .milestone:
            return .milestone
        case .breakthrough:
            return .breakthrough
        case .progress:
            return .progress
        case .accomplishment:
            return .accomplishment
        }
    }
    
    // MARK: - TTS Voice Characteristics
    
    /// TTS voice characteristics optimized for Ollama speech synthesis
    struct TTSVoiceCharacteristics {
        let pacing: Double // Words per minute (120-180 typical)
        let pitch: Double // Relative pitch (0.8-1.2, where 1.0 is neutral)
        let warmth: Double // Voice warmth (0.0-1.0)
        let clarity: Double // Articulation clarity (0.0-1.0)
        let energy: Double // Vocal energy (0.0-1.0)
        let pauseFrequency: Double // Pause frequency (0.0-1.0, higher = more pauses)
        let emphasis: Double // Emphasis on key words (0.0-1.0)
    }
    
    /// Get TTS voice characteristics for a tone
    static func ttsVoiceCharacteristics(for tone: AuroraTone) -> TTSVoiceCharacteristics {
        switch tone {
        // Ritual tones
        case .clarityCharge:
            return TTSVoiceCharacteristics(
                pacing: 145, // Energetic but clear
                pitch: 1.05, // Slightly elevated
                warmth: 0.7,
                clarity: 0.9,
                energy: 0.85,
                pauseFrequency: 0.3,
                emphasis: 0.75
            )
        case .releaseReview:
            return TTSVoiceCharacteristics(
                pacing: 120, // Slower, more relaxed
                pitch: 0.95, // Slightly lower
                warmth: 0.85,
                clarity: 0.8,
                energy: 0.5,
                pauseFrequency: 0.6,
                emphasis: 0.4
            )
        
        // Focus & Work tones
        case .deepFocus:
            return TTSVoiceCharacteristics(
                pacing: 130, // Measured
                pitch: 1.0, // Neutral
                warmth: 0.6,
                clarity: 0.95,
                energy: 0.7,
                pauseFrequency: 0.4,
                emphasis: 0.65
            )
        case .creativeFlow:
            return TTSVoiceCharacteristics(
                pacing: 150, // Flowing
                pitch: 1.08, // Slightly higher
                warmth: 0.75,
                clarity: 0.85,
                energy: 0.8,
                pauseFrequency: 0.35,
                emphasis: 0.7
            )
        case .productiveMomentum:
            return TTSVoiceCharacteristics(
                pacing: 155, // Forward-moving
                pitch: 1.03,
                warmth: 0.7,
                clarity: 0.88,
                energy: 0.82,
                pauseFrequency: 0.3,
                emphasis: 0.72
            )
        case .analytical:
            return TTSVoiceCharacteristics(
                pacing: 125, // Precise
                pitch: 0.98, // Slightly lower
                warmth: 0.5,
                clarity: 0.98,
                energy: 0.65,
                pauseFrequency: 0.5,
                emphasis: 0.8
            )
        
        // Emotional & Reflective tones
        case .reflective:
            return TTSVoiceCharacteristics(
                pacing: 115, // Thoughtful
                pitch: 0.93, // Lower
                warmth: 0.8,
                clarity: 0.75,
                energy: 0.45,
                pauseFrequency: 0.7,
                emphasis: 0.5
            )
        case .contemplative:
            return TTSVoiceCharacteristics(
                pacing: 110, // Very slow
                pitch: 0.9, // Lower
                warmth: 0.75,
                clarity: 0.7,
                energy: 0.4,
                pauseFrequency: 0.75,
                emphasis: 0.45
            )
        case .supportive:
            return TTSVoiceCharacteristics(
                pacing: 125, // Comfortable
                pitch: 0.97, // Slightly lower
                warmth: 0.9,
                clarity: 0.82,
                energy: 0.6,
                pauseFrequency: 0.55,
                emphasis: 0.6
            )
        case .celebratory:
            return TTSVoiceCharacteristics(
                pacing: 160, // Enthusiastic
                pitch: 1.1, // Higher
                warmth: 0.85,
                clarity: 0.88,
                energy: 0.95,
                pauseFrequency: 0.25,
                emphasis: 0.85
            )
        
        // Guidance tones
        case .gentleGuidance:
            return TTSVoiceCharacteristics(
                pacing: 118, // Patient
                pitch: 0.94, // Lower
                warmth: 0.88,
                clarity: 0.78,
                energy: 0.5,
                pauseFrequency: 0.65,
                emphasis: 0.55
            )
        case .confidentDirection:
            return TTSVoiceCharacteristics(
                pacing: 140, // Clear
                pitch: 1.02, // Slightly elevated
                warmth: 0.65,
                clarity: 0.92,
                energy: 0.75,
                pauseFrequency: 0.4,
                emphasis: 0.78
            )
        case .encouraging:
            return TTSVoiceCharacteristics(
                pacing: 135, // Uplifting
                pitch: 1.04, // Slightly higher
                warmth: 0.82,
                clarity: 0.85,
                energy: 0.78,
                pauseFrequency: 0.45,
                emphasis: 0.7
            )
        case .reassuring:
            return TTSVoiceCharacteristics(
                pacing: 122, // Calming
                pitch: 0.96, // Lower
                warmth: 0.87,
                clarity: 0.8,
                energy: 0.55,
                pauseFrequency: 0.6,
                emphasis: 0.58
            )
        
        // Insight tones
        case .insightful:
            return TTSVoiceCharacteristics(
                pacing: 128, // Thoughtful
                pitch: 0.99, // Neutral
                warmth: 0.72,
                clarity: 0.9,
                energy: 0.68,
                pauseFrequency: 0.5,
                emphasis: 0.72
            )
        case .analyticalInsight:
            return TTSVoiceCharacteristics(
                pacing: 123, // Precise
                pitch: 0.97, // Slightly lower
                warmth: 0.55,
                clarity: 0.96,
                energy: 0.62,
                pauseFrequency: 0.55,
                emphasis: 0.82
            )
        case .patternRecognition:
            return TTSVoiceCharacteristics(
                pacing: 132, // Connecting
                pitch: 1.01, // Slightly elevated
                warmth: 0.68,
                clarity: 0.88,
                energy: 0.7,
                pauseFrequency: 0.45,
                emphasis: 0.75
            )
        
        // Error & Problem tones
        case .gentleError:
            return TTSVoiceCharacteristics(
                pacing: 118, // Patient
                pitch: 0.94, // Lower
                warmth: 0.85,
                clarity: 0.82,
                energy: 0.5,
                pauseFrequency: 0.65,
                emphasis: 0.6
            )
        case .constructiveFeedback:
            return TTSVoiceCharacteristics(
                pacing: 128, // Clear
                pitch: 0.99, // Neutral
                warmth: 0.75,
                clarity: 0.9,
                energy: 0.65,
                pauseFrequency: 0.5,
                emphasis: 0.7
            )
        case .problemSolving:
            return TTSVoiceCharacteristics(
                pacing: 125, // Methodical
                pitch: 0.98, // Slightly lower
                warmth: 0.6,
                clarity: 0.95,
                energy: 0.68,
                pauseFrequency: 0.5,
                emphasis: 0.75
            )
        case .troubleshooting:
            return TTSVoiceCharacteristics(
                pacing: 122, // Systematic
                pitch: 0.97, // Slightly lower
                warmth: 0.55,
                clarity: 0.97,
                energy: 0.62,
                pauseFrequency: 0.55,
                emphasis: 0.78
            )
        
        // Learning & Educational tones
        case .educational:
            return TTSVoiceCharacteristics(
                pacing: 130, // Clear
                pitch: 1.0, // Neutral
                warmth: 0.7,
                clarity: 0.92,
                energy: 0.7,
                pauseFrequency: 0.45,
                emphasis: 0.72
            )
        case .tutorial:
            return TTSVoiceCharacteristics(
                pacing: 120, // Patient
                pitch: 0.96, // Lower
                warmth: 0.8,
                clarity: 0.88,
                energy: 0.6,
                pauseFrequency: 0.6,
                emphasis: 0.68
            )
        case .discovery:
            return TTSVoiceCharacteristics(
                pacing: 138, // Curious
                pitch: 1.06, // Slightly higher
                warmth: 0.78,
                clarity: 0.85,
                energy: 0.75,
                pauseFrequency: 0.4,
                emphasis: 0.7
            )
        case .exploratory:
            return TTSVoiceCharacteristics(
                pacing: 142, // Adventurous
                pitch: 1.05, // Slightly higher
                warmth: 0.72,
                clarity: 0.83,
                energy: 0.78,
                pauseFrequency: 0.38,
                emphasis: 0.72
            )
        
        // Social & Communication tones
        case .collaborative:
            return TTSVoiceCharacteristics(
                pacing: 133, // Inclusive
                pitch: 1.0, // Neutral
                warmth: 0.85,
                clarity: 0.86,
                energy: 0.72,
                pauseFrequency: 0.48,
                emphasis: 0.68
            )
        case .conversational:
            return TTSVoiceCharacteristics(
                pacing: 140, // Natural
                pitch: 1.01, // Slightly elevated
                warmth: 0.82,
                clarity: 0.8,
                energy: 0.7,
                pauseFrequency: 0.42,
                emphasis: 0.65
            )
        case .empathetic:
            return TTSVoiceCharacteristics(
                pacing: 124, // Understanding
                pitch: 0.96, // Lower
                warmth: 0.92,
                clarity: 0.78,
                energy: 0.58,
                pauseFrequency: 0.62,
                emphasis: 0.62
            )
        case .diplomatic:
            return TTSVoiceCharacteristics(
                pacing: 127, // Balanced
                pitch: 0.98, // Slightly lower
                warmth: 0.7,
                clarity: 0.87,
                energy: 0.65,
                pauseFrequency: 0.52,
                emphasis: 0.7
            )
        
        // Health & Wellness tones
        case .restorative:
            return TTSVoiceCharacteristics(
                pacing: 112, // Healing
                pitch: 0.92, // Lower
                warmth: 0.88,
                clarity: 0.75,
                energy: 0.42,
                pauseFrequency: 0.72,
                emphasis: 0.48
            )
        case .mindful:
            return TTSVoiceCharacteristics(
                pacing: 115, // Present
                pitch: 0.93, // Lower
                warmth: 0.8,
                clarity: 0.72,
                energy: 0.45,
                pauseFrequency: 0.7,
                emphasis: 0.5
            )
        case .recovery:
            return TTSVoiceCharacteristics(
                pacing: 113, // Supportive
                pitch: 0.91, // Lower
                warmth: 0.87,
                clarity: 0.73,
                energy: 0.43,
                pauseFrequency: 0.73,
                emphasis: 0.47
            )
        case .rejuvenating:
            return TTSVoiceCharacteristics(
                pacing: 128, // Refreshing
                pitch: 1.0, // Neutral
                warmth: 0.83,
                clarity: 0.85,
                energy: 0.72,
                pauseFrequency: 0.5,
                emphasis: 0.68
            )
        
        // Achievement & Milestone tones
        case .milestone:
            return TTSVoiceCharacteristics(
                pacing: 148, // Acknowledging
                pitch: 1.07, // Higher
                warmth: 0.88,
                clarity: 0.9,
                energy: 0.88,
                pauseFrequency: 0.35,
                emphasis: 0.8
            )
        case .breakthrough:
            return TTSVoiceCharacteristics(
                pacing: 155, // Exciting
                pitch: 1.12, // Higher
                warmth: 0.9,
                clarity: 0.92,
                energy: 0.95,
                pauseFrequency: 0.3,
                emphasis: 0.88
            )
        case .progress:
            return TTSVoiceCharacteristics(
                pacing: 138, // Positive
                pitch: 1.04, // Slightly higher
                warmth: 0.85,
                clarity: 0.87,
                energy: 0.8,
                pauseFrequency: 0.4,
                emphasis: 0.75
            )
        case .accomplishment:
            return TTSVoiceCharacteristics(
                pacing: 145, // Proud
                pitch: 1.06, // Higher
                warmth: 0.87,
                clarity: 0.89,
                energy: 0.85,
                pauseFrequency: 0.38,
                emphasis: 0.82
            )
        
        // Warning & Alert tones
        case .alert:
            return TTSVoiceCharacteristics(
                pacing: 150, // Urgent
                pitch: 1.08, // Higher
                warmth: 0.6,
                clarity: 0.95,
                energy: 0.9,
                pauseFrequency: 0.35,
                emphasis: 0.9
            )
        case .caution:
            return TTSVoiceCharacteristics(
                pacing: 135, // Careful
                pitch: 1.03, // Slightly higher
                warmth: 0.65,
                clarity: 0.9,
                energy: 0.75,
                pauseFrequency: 0.45,
                emphasis: 0.8
            )
        case .gentleWarning:
            return TTSVoiceCharacteristics(
                pacing: 125, // Soft
                pitch: 0.97, // Slightly lower
                warmth: 0.82,
                clarity: 0.83,
                energy: 0.6,
                pauseFrequency: 0.58,
                emphasis: 0.65
            )
        case .importantNotice:
            return TTSVoiceCharacteristics(
                pacing: 140, // Clear
                pitch: 1.02, // Slightly elevated
                warmth: 0.7,
                clarity: 0.93,
                energy: 0.78,
                pauseFrequency: 0.42,
                emphasis: 0.78
            )
        
        // Transition & Change tones
        case .smoothTransition:
            return TTSVoiceCharacteristics(
                pacing: 130, // Seamless
                pitch: 1.0, // Neutral
                warmth: 0.75,
                clarity: 0.85,
                energy: 0.68,
                pauseFrequency: 0.48,
                emphasis: 0.7
            )
        case .phaseShift:
            return TTSVoiceCharacteristics(
                pacing: 135, // Transformative
                pitch: 1.03, // Slightly elevated
                warmth: 0.72,
                clarity: 0.88,
                energy: 0.75,
                pauseFrequency: 0.43,
                emphasis: 0.75
            )
        case .adaptation:
            return TTSVoiceCharacteristics(
                pacing: 128, // Flexible
                pitch: 0.99, // Neutral
                warmth: 0.73,
                clarity: 0.86,
                energy: 0.7,
                pauseFrequency: 0.47,
                emphasis: 0.72
            )
        case .transformation:
            return TTSVoiceCharacteristics(
                pacing: 142, // Profound
                pitch: 1.05, // Slightly higher
                warmth: 0.78,
                clarity: 0.89,
                energy: 0.82,
                pauseFrequency: 0.4,
                emphasis: 0.78
            )
        
        // Time-based tones
        case .morningVibes:
            return TTSVoiceCharacteristics(
                pacing: 145, // Fresh
                pitch: 1.05, // Slightly elevated
                warmth: 0.75,
                clarity: 0.9,
                energy: 0.83,
                pauseFrequency: 0.35,
                emphasis: 0.75
            )
        case .afternoonEnergy:
            return TTSVoiceCharacteristics(
                pacing: 150, // Active
                pitch: 1.04, // Slightly elevated
                warmth: 0.72,
                clarity: 0.88,
                energy: 0.85,
                pauseFrequency: 0.32,
                emphasis: 0.77
            )
        case .eveningCalm:
            return TTSVoiceCharacteristics(
                pacing: 120, // Relaxed
                pitch: 0.95, // Lower
                warmth: 0.85,
                clarity: 0.8,
                energy: 0.55,
                pauseFrequency: 0.6,
                emphasis: 0.5
            )
        case .nightReflection:
            return TTSVoiceCharacteristics(
                pacing: 110, // Quiet
                pitch: 0.9, // Lower
                warmth: 0.8,
                clarity: 0.72,
                energy: 0.4,
                pauseFrequency: 0.75,
                emphasis: 0.45
            )
        
        // Workload & Context tones
        case .lightLoad:
            return TTSVoiceCharacteristics(
                pacing: 125, // Comfortable
                pitch: 0.98, // Slightly lower
                warmth: 0.8,
                clarity: 0.82,
                energy: 0.65,
                pauseFrequency: 0.55,
                emphasis: 0.62
            )
        case .heavyLoad:
            return TTSVoiceCharacteristics(
                pacing: 148, // Intense
                pitch: 1.06, // Higher
                warmth: 0.65,
                clarity: 0.92,
                energy: 0.88,
                pauseFrequency: 0.38,
                emphasis: 0.85
            )
        case .balanced:
            return TTSVoiceCharacteristics(
                pacing: 130, // Equilibrium
                pitch: 1.0, // Neutral
                warmth: 0.75,
                clarity: 0.85,
                energy: 0.7,
                pauseFrequency: 0.5,
                emphasis: 0.7
            )
        case .overloaded:
            return TTSVoiceCharacteristics(
                pacing: 152, // Urgent
                pitch: 1.09, // Higher
                warmth: 0.6,
                clarity: 0.94,
                energy: 0.92,
                pauseFrequency: 0.33,
                emphasis: 0.9
            )
        
        // Recovery & Reset tones
        case .rest:
            return TTSVoiceCharacteristics(
                pacing: 108, // Peaceful
                pitch: 0.89, // Lower
                warmth: 0.86,
                clarity: 0.7,
                energy: 0.38,
                pauseFrequency: 0.78,
                emphasis: 0.42
            )
        case .recharge:
            return TTSVoiceCharacteristics(
                pacing: 126, // Energizing
                pitch: 1.0, // Neutral
                warmth: 0.84,
                clarity: 0.84,
                energy: 0.72,
                pauseFrequency: 0.52,
                emphasis: 0.68
            )
        case .reset:
            return TTSVoiceCharacteristics(
                pacing: 132, // Fresh start
                pitch: 1.01, // Slightly elevated
                warmth: 0.76,
                clarity: 0.87,
                energy: 0.74,
                pauseFrequency: 0.46,
                emphasis: 0.72
            )
        case .pause:
            return TTSVoiceCharacteristics(
                pacing: 115, // Temporary stop
                pitch: 0.94, // Lower
                warmth: 0.81,
                clarity: 0.76,
                energy: 0.48,
                pauseFrequency: 0.68,
                emphasis: 0.52
            )
        }
    }
    
    /// Get TTS prompt instructions for Ollama based on tone
    static func ttsPromptInstructions(for tone: AuroraTone) -> String {
        let voice = ttsVoiceCharacteristics(for: tone)
        
        var instructions = "Speak with the following characteristics: "
        instructions += "pace of approximately \(Int(voice.pacing)) words per minute, "
        instructions += "\(voice.pitch < 1.0 ? "slightly lower" : voice.pitch > 1.0 ? "slightly higher" : "neutral") pitch, "
        instructions += "\(voice.warmth > 0.7 ? "warm and" : "") "
        instructions += "\(voice.clarity > 0.85 ? "clear articulation" : "natural speech"), "
        instructions += "\(voice.energy > 0.7 ? "energetic" : voice.energy < 0.5 ? "calm and measured" : "balanced") delivery, "
        instructions += "\(voice.pauseFrequency > 0.6 ? "with thoughtful pauses" : voice.pauseFrequency < 0.4 ? "with minimal pauses" : "with natural pauses"), "
        instructions += "and \(voice.emphasis > 0.7 ? "strong emphasis" : "subtle emphasis") on key words. "
        instructions += "Tone should be \(summaryTone(for: tone))."
        
        return instructions
    }
    
    // MARK: - Tone Blending & Transitions
    
    /// Blend two tones together for smooth transitions
    static func blendTones(_ tone1: AuroraTone, _ tone2: AuroraTone, ratio: Double) -> AuroraTone {
        // For now, return the dominant tone based on ratio
        // Future: Could create intermediate tones or blend characteristics
        return ratio >= 0.5 ? tone1 : tone2
    }
    
    /// Get transition tone between two states
    static func transitionTone(from: AuroraTone, to: AuroraTone) -> AuroraTone {
        // Handle bidirectional transitions
        let transitionPairs: [(AuroraTone, AuroraTone, AuroraTone)] = [
            // Ritual transitions
            (.clarityCharge, .releaseReview, .smoothTransition),
            (.releaseReview, .clarityCharge, .smoothTransition),
            
            // Focus transitions
            (.deepFocus, .rest, .phaseShift),
            (.rest, .deepFocus, .smoothTransition),
            (.productiveMomentum, .pause, .phaseShift),
            (.pause, .productiveMomentum, .smoothTransition),
            (.productiveMomentum, .rest, .phaseShift),
            (.rest, .productiveMomentum, .smoothTransition),
            (.clarityCharge, .rest, .phaseShift),
            (.rest, .clarityCharge, .smoothTransition),
            (.recharge, .productiveMomentum, .smoothTransition),
            (.productiveMomentum, .recharge, .phaseShift),
            
            // Emotional transitions
            (.reflective, .encouraging, .smoothTransition),
            (.encouraging, .reflective, .smoothTransition),
            (.reflective, .celebratory, .smoothTransition),
            (.celebratory, .reflective, .smoothTransition),
            
            // Guidance transitions
            (.gentleGuidance, .confidentDirection, .smoothTransition),
            (.confidentDirection, .gentleGuidance, .smoothTransition),
            
            // Insight transitions
            (.insightful, .analyticalInsight, .smoothTransition),
            (.analyticalInsight, .insightful, .smoothTransition),
            (.reflective, .insightful, .smoothTransition),
            (.insightful, .reflective, .smoothTransition)
        ]
        
        // Check for specific transition pairs
        for (fromTone, toTone, transitionTone) in transitionPairs {
            if from == fromTone && to == toTone {
                return transitionTone
            }
        }
        
        // Use phase shift for significant category changes
        let fromCategory = category(for: from)
        let toCategory = category(for: to)
        
        if fromCategory != toCategory {
            // Significant category change - use phase shift
            let significantCategoryChanges: [(ToneCategory, ToneCategory)] = [
                (.focus, .recovery),
                (.recovery, .focus),
                (.ritual, .recovery),
                (.recovery, .ritual),
                (.emotional, .focus),
                (.focus, .emotional)
            ]
            
            if significantCategoryChanges.contains(where: { ($0.0 == fromCategory && $0.1 == toCategory) || ($0.0 == toCategory && $0.1 == fromCategory) }) {
                return .phaseShift
            }
        }
        
        // Default to smooth transition for most cases
        return .smoothTransition
    }
    
    /// Scale tone intensity (for dynamic adjustments)
    static func scaleToneIntensity(_ tone: AuroraTone, intensity: Double) -> AuroraTone {
        // Intensity 0.0-1.0, where 1.0 is full intensity
        // For now, return the tone as-is (future: could adjust opacity/energy)
        return tone
    }
    
    /// Calculate transition intensity between two tones (0.0-1.0)
    /// Higher intensity = more significant change, affects memory decay rate
    static func calculateTransitionIntensity(from: AuroraTone, to: AuroraTone) -> Double {
        // If same tone, no intensity
        if from == to {
            return 0.0
        }
        
        let fromCategory = category(for: from)
        let toCategory = category(for: to)
        
        // Category change = high intensity (0.8-1.0)
        if fromCategory != toCategory {
            let significantCategoryChanges: [(ToneCategory, ToneCategory)] = [
                (.focus, .recovery),
                (.recovery, .focus),
                (.ritual, .recovery),
                (.recovery, .ritual),
                (.emotional, .focus),
                (.focus, .emotional)
            ]
            
            if significantCategoryChanges.contains(where: { ($0.0 == fromCategory && $0.1 == toCategory) || ($0.0 == toCategory && $0.1 == fromCategory) }) {
                return 1.0 // Maximum intensity for major category shifts
            }
            return 0.8 // High intensity for category changes
        }
        
        // Same category, different tones = medium intensity (0.4-0.6)
        // Check for complementary tones (opposite ends of spectrum)
        let complementaryPairs: [(AuroraTone, AuroraTone)] = [
            (.clarityCharge, .releaseReview),
            (.deepFocus, .rest),
            (.productiveMomentum, .pause),
            (.reflective, .encouraging),
            (.gentleGuidance, .confidentDirection)
        ]
        
        if complementaryPairs.contains(where: { ($0.0 == from && $0.1 == to) || ($0.0 == to && $0.1 == from) }) {
            return 0.6 // Medium-high intensity for complementary pairs
        }
        
        // Similar tones = low intensity (0.2-0.4)
        return 0.3 // Low-medium intensity for similar tones
    }
    
    // MARK: - Tone Combinations
    
    /// Get combined tone for complex states (e.g., "focused but tired")
    static func combinedTone(primary: AuroraTone, secondary: AuroraTone, weight: Double = 0.7) -> AuroraTone {
        // Weight: 0.0-1.0, how much primary vs secondary
        return weight >= 0.5 ? primary : secondary
    }
    
    /// Get tone for multi-context situations
    static func contextualTone(
        emotionalState: EmotionalState? = nil,
        timeOfDay: TimeOfDayContext? = nil,
        workload: WorkloadLevel? = nil,
        ritualType: FocusRitualType? = nil
    ) -> AuroraTone {
        // Priority: ritual > emotional state > workload > time of day
        if let ritual = ritualType {
            return tone(for: ritual)
        }
        
        if let emotion = emotionalState {
            return tone(for: emotion)
        }
        
        if let load = workload {
            return tone(for: load)
        }
        
        if let time = timeOfDay {
            return tone(for: time)
        }
        
        return .balanced // Default
    }
    
    // MARK: - Tone Utilities
    
    /// Get all tones in a category
    static func tones(in category: ToneCategory) -> [AuroraTone] {
        switch category {
        case .ritual:
            return [.clarityCharge, .releaseReview]
        case .focus:
            return [.deepFocus, .creativeFlow, .productiveMomentum, .analytical]
        case .emotional:
            return [.reflective, .contemplative, .supportive, .celebratory]
        case .guidance:
            return [.gentleGuidance, .confidentDirection, .encouraging, .reassuring]
        case .insight:
            return [.insightful, .analyticalInsight, .patternRecognition]
        case .error:
            return [.gentleError, .constructiveFeedback, .problemSolving, .troubleshooting]
        case .learning:
            return [.educational, .tutorial, .discovery, .exploratory]
        case .social:
            return [.collaborative, .conversational, .empathetic, .diplomatic]
        case .wellness:
            return [.restorative, .mindful, .recovery, .rejuvenating]
        case .achievement:
            return [.milestone, .breakthrough, .progress, .accomplishment]
        case .warning:
            return [.alert, .caution, .gentleWarning, .importantNotice]
        case .transition:
            return [.smoothTransition, .phaseShift, .adaptation, .transformation]
        case .timeBased:
            return [.morningVibes, .afternoonEnergy, .eveningCalm, .nightReflection]
        case .workload:
            return [.lightLoad, .heavyLoad, .balanced, .overloaded]
        case .recovery:
            return [.rest, .recharge, .reset, .pause]
        }
    }
    
    /// Get tone category for a tone
    static func category(for tone: AuroraTone) -> ToneCategory {
        switch tone {
        case .clarityCharge, .releaseReview:
            return .ritual
        case .deepFocus, .creativeFlow, .productiveMomentum, .analytical:
            return .focus
        case .reflective, .contemplative, .supportive, .celebratory:
            return .emotional
        case .gentleGuidance, .confidentDirection, .encouraging, .reassuring:
            return .guidance
        case .insightful, .analyticalInsight, .patternRecognition:
            return .insight
        case .gentleError, .constructiveFeedback, .problemSolving, .troubleshooting:
            return .error
        case .educational, .tutorial, .discovery, .exploratory:
            return .learning
        case .collaborative, .conversational, .empathetic, .diplomatic:
            return .social
        case .restorative, .mindful, .recovery, .rejuvenating:
            return .wellness
        case .milestone, .breakthrough, .progress, .accomplishment:
            return .achievement
        case .alert, .caution, .gentleWarning, .importantNotice:
            return .warning
        case .smoothTransition, .phaseShift, .adaptation, .transformation:
            return .transition
        case .morningVibes, .afternoonEnergy, .eveningCalm, .nightReflection:
            return .timeBased
        case .lightLoad, .heavyLoad, .balanced, .overloaded:
            return .workload
        case .rest, .recharge, .reset, .pause:
            return .recovery
        }
    }
    
    /// Get complementary tone (opposite energy)
    static func complementaryTone(for tone: AuroraTone) -> AuroraTone {
        switch tone {
        case .clarityCharge:
            return .releaseReview
        case .releaseReview:
            return .clarityCharge
        case .deepFocus:
            return .rest
        case .productiveMomentum:
            return .pause
        case .heavyLoad:
            return .lightLoad
        case .overloaded:
            return .rest
        default:
            return .balanced
        }
    }
    
    /// Get similar tones (same energy level)
    static func similarTones(to tone: AuroraTone, limit: Int = 3) -> [AuroraTone] {
        let category = category(for: tone)
        let categoryTones = tones(in: category)
        return Array(categoryTones.filter { $0 != tone }.prefix(limit))
    }
    
    // MARK: - Tone Prediction
    
    /// Predict the next tone based on conversation patterns
    /// Analyzes user's last 3 messages and Aurora's last 2 tones to forecast probable next tone
    /// Optionally uses historical accuracy data, reliability profiles, temporal emotional memory, and ERI to weight predictions
    static func predictNextTone(
        userMessages: [String],
        auroraTones: [AuroraTone],
        toneAccuracyScores: [AuroraTone: Double]? = nil,
        adaptiveBiasFactors: [String: Double]? = nil, // Key: "predictedTone_actualTone", Value: bias factor
        reliabilityProfiles: [AuroraTone: ToneReliabilityProfile]? = nil,
        emotionalMomentum: (momentum: Double, trend: EmotionalTrend, confidence: Double)? = nil,
        rollingBaseline: Double? = nil,
        eriIndex: Double? = nil
    ) -> (predictedTone: AuroraTone?, confidence: Double, reasoning: String) {
        guard !userMessages.isEmpty || !auroraTones.isEmpty else {
            return (nil, 0.0, "Insufficient conversation history")
        }
        
        var toneScores: [AuroraTone: Double] = [:]
        var reasoning: [String] = []
        
        // Analyze user message patterns
        for (index, message) in userMessages.enumerated() {
            let weight = Double(userMessages.count - index) / Double(userMessages.count) // More recent = higher weight
            let messageLower = message.lowercased()
            
            // Pattern matching for tone indicators
            if messageLower.contains("congratulations") || messageLower.contains("well done") || messageLower.contains("great job") {
                toneScores[.celebratory, default: 0.0] += 0.4 * weight
                toneScores[.encouraging, default: 0.0] += 0.3 * weight
            }
            
            if messageLower.contains("help") || messageLower.contains("stuck") || messageLower.contains("problem") {
                toneScores[.problemSolving, default: 0.0] += 0.4 * weight
                toneScores[.supportive, default: 0.0] += 0.3 * weight
                toneScores[.gentleGuidance, default: 0.0] += 0.2 * weight
            }
            
            if messageLower.contains("reflect") || messageLower.contains("think") || messageLower.contains("consider") {
                toneScores[.reflective, default: 0.0] += 0.5 * weight
                toneScores[.contemplative, default: 0.0] += 0.3 * weight
            }
            
            if messageLower.contains("start") || messageLower.contains("begin") || messageLower.contains("let's") {
                toneScores[.clarityCharge, default: 0.0] += 0.4 * weight
                toneScores[.productiveMomentum, default: 0.0] += 0.3 * weight
            }
            
            if messageLower.contains("tired") || messageLower.contains("exhausted") || messageLower.contains("rest") {
                toneScores[.rest, default: 0.0] += 0.5 * weight
                toneScores[.restorative, default: 0.0] += 0.3 * weight
            }
            
            if messageLower.contains("focus") || messageLower.contains("concentrate") || messageLower.contains("deep work") {
                toneScores[.deepFocus, default: 0.0] += 0.5 * weight
                toneScores[.productiveMomentum, default: 0.0] += 0.3 * weight
            }
            
            if messageLower.contains("insight") || messageLower.contains("pattern") || messageLower.contains("notice") {
                toneScores[.insightful, default: 0.0] += 0.4 * weight
                toneScores[.analyticalInsight, default: 0.0] += 0.3 * weight
            }
            
            if messageLower.contains("thank") || messageLower.contains("grateful") || messageLower.contains("appreciate") {
                toneScores[.reflective, default: 0.0] += 0.4 * weight
                toneScores[.supportive, default: 0.0] += 0.3 * weight
                toneScores[.celebratory, default: 0.0] += 0.2 * weight
            }
            
            // Question patterns
            if messageLower.contains("?") {
                let questionCount = Double(messageLower.filter { $0 == "?" }.count)
                toneScores[.gentleGuidance, default: 0.0] += 0.2 * weight * min(questionCount, 2.0)
                toneScores[.supportive, default: 0.0] += 0.15 * weight * min(questionCount, 2.0)
            }
        }
        
        // Analyze Aurora's recent tones for continuity and transitions
        if !auroraTones.isEmpty {
            let lastTone = auroraTones.last!
            let lastCategory = category(for: lastTone)
            
            // Continuity: Similar tones in same category get boost
            let similarTones = similarTones(to: lastTone, limit: 5)
            for similarTone in similarTones {
                toneScores[similarTone, default: 0.0] += 0.3
            }
            reasoning.append("Continuity from recent \(lastTone.displayName) tone suggests similar tones in \(lastCategory) category")
            
            // Transition patterns: If we have 2 tones, check for transition direction
            if auroraTones.count >= 2 {
                let previousTone = auroraTones[auroraTones.count - 2]
                let currentTone = lastTone
                
                // If tones are different, predict continuation of transition
                if previousTone != currentTone {
                    let transitionTone = transitionTone(from: previousTone, to: currentTone)
                    toneScores[transitionTone, default: 0.0] += 0.4
                    reasoning.append("Transition from \(previousTone.displayName) to \(currentTone.displayName) suggests \(transitionTone.displayName)")
                    
                    // Also boost tones in the target category
                    let targetCategory = category(for: currentTone)
                    let targetCategoryTones = tones(in: targetCategory)
                    for tone in targetCategoryTones {
                        toneScores[tone, default: 0.0] += 0.2
                    }
                } else {
                    // Same tone repeated - predict continuation or slight variation
                    toneScores[lastTone, default: 0.0] += 0.5
                    for similarTone in similarTones.prefix(2) {
                        toneScores[similarTone, default: 0.0] += 0.25
                    }
                    reasoning.append("Repeated \(lastTone.displayName) tone suggests continuation or similar variation")
                }
            } else {
                // Only one tone - predict continuation or category expansion
                toneScores[lastTone, default: 0.0] += 0.4
                for similarTone in similarTones.prefix(3) {
                    toneScores[similarTone, default: 0.0] += 0.2
                }
                reasoning.append("Single recent tone suggests continuation or category expansion")
            }
        }
        
        // Apply historical accuracy weighting if available
        if let accuracyScores = toneAccuracyScores {
            for (tone, score) in toneScores {
                if let accuracy = accuracyScores[tone] {
                    // Boost scores for tones with higher historical accuracy
                    // Accuracy 0.5 (neutral) = no change, 1.0 (perfect) = +50% boost
                    let accuracyBoost = (accuracy - 0.5) * 0.5 // -0.25 to +0.25 multiplier
                    toneScores[tone] = score * (1.0 + accuracyBoost)
                    if accuracy > 0.7 {
                        reasoning.append("Historical accuracy (\(String(format: "%.0f", accuracy * 100))%) favors \(tone.displayName)")
                    }
                }
            }
        }
        
        // Apply adaptive bias factors for tone pairs
        if let biasFactors = adaptiveBiasFactors, !auroraTones.isEmpty {
            let lastTone = auroraTones.last!
            for (tone, score) in toneScores {
                let pairKey = "\(lastTone.rawValue)_\(tone.rawValue)"
                if let biasFactor = biasFactors[pairKey] {
                    // Apply bias factor (1.0-1.5x)
                    toneScores[tone] = score * biasFactor
                    if biasFactor > 1.2 {
                        reasoning.append("Adaptive bias (\(String(format: "%.1f", biasFactor))x) favors transition to \(tone.displayName)")
                    }
                }
            }
        }
        
        // Apply reliability profile weighting
        if let profiles = reliabilityProfiles {
            for (tone, score) in toneScores {
                if let profile = profiles[tone] {
                    // Higher stability = more reliable predictions
                    let stabilityBoost = profile.stability * 0.3 // Up to +30% boost
                    // Lower volatility = more consistent
                    let volatilityPenalty = profile.volatility * 0.2 // Up to -20% penalty
                    // Positive sentiment = more favorable
                    let sentimentBoost = max(0.0, profile.sentimentPolarity) * 0.15 // Up to +15% boost
                    
                    let reliabilityMultiplier = 1.0 + stabilityBoost - volatilityPenalty + sentimentBoost
                    toneScores[tone] = score * reliabilityMultiplier
                    
                    if profile.stability > 0.7 {
                        reasoning.append("High stability (\(String(format: "%.0f", profile.stability * 100))%) for \(tone.displayName) increases confidence")
                    }
                }
            }
        }
        
        // Apply temporal emotional memory weighting
        if let momentum = emotionalMomentum, momentum.confidence > 0.5 {
            // Bias toward tones that match emotional momentum
            for (tone, score) in toneScores {
                let toneCategory = category(for: tone)
                
                // Positive momentum → favor positive/energetic tones
                if momentum.trend == .improving && momentum.momentum > 0.1 {
                    if toneCategory == .emotional || toneCategory == .achievement || tone == .encouraging || tone == .celebratory {
                        toneScores[tone] = score * 1.15
                        reasoning.append("Positive emotional momentum favors \(tone.displayName)")
                    }
                }
                
                // Negative momentum → favor supportive/calming tones
                if momentum.trend == .declining && momentum.momentum < -0.1 {
                    if toneCategory == .wellness || toneCategory == .guidance || tone == .supportive || tone == .reassuring {
                        toneScores[tone] = score * 1.15
                        reasoning.append("Calming emotional momentum favors \(tone.displayName)")
                    }
                }
            }
        }
        
        // Apply rolling baseline bias
        if let baseline = rollingBaseline, abs(baseline) > 0.2 {
            // Positive baseline → favor matching positive tones
            if baseline > 0.2 {
                for (tone, score) in toneScores {
                    let toneCategory = category(for: tone)
                    if toneCategory == .emotional || tone == .encouraging || tone == .celebratory {
                        toneScores[tone] = score * 1.1
                    }
                }
            }
            
            // Negative/calm baseline → favor matching calm tones
            if baseline < -0.2 {
                for (tone, score) in toneScores {
                    let toneCategory = category(for: tone)
                    if toneCategory == .wellness || tone == .rest || tone == .restorative || tone == .mindful {
                        toneScores[tone] = score * 1.1
                    }
                }
            }
        }
        
        // Apply ERI-based tone weighting adjustment
        // Negative ERI (discord) → increase emotional expression density to resynchronize
        if let eri = eriIndex, eri < -0.2 {
            let discordIntensity = abs(eri)
            // Boost tones that align with ARTE emotional state (if available)
            if let glassSystem = GlassColorSystem.active {
                let arteTone = tone(for: glassSystem.emotionalState)
                for (tone, score) in toneScores {
                    if tone == arteTone {
                        // Strong boost for ARTE-aligned tone
                        toneScores[tone] = score * (1.0 + discordIntensity * 0.3)
                        reasoning.append("ERI discord (\(String(format: "%.2f", eri))) - boosting \(tone.displayName) for resynchronization")
                    } else if category(for: tone) == category(for: arteTone) {
                        // Moderate boost for same category
                        toneScores[tone] = score * (1.0 + discordIntensity * 0.15)
                    }
                }
            }
        }
        
        // Normalize scores and find top prediction
        let maxScore = toneScores.values.max() ?? 0.0
        guard maxScore > 0.0 else {
            return (nil, 0.0, "No clear tone pattern detected")
        }
        
        // Normalize to 0.0-1.0 confidence scale
        let normalizedScores = toneScores.mapValues { $0 / maxScore }
        
        // Find top prediction
        let sorted = normalizedScores.sorted { $0.value > $1.value }
        guard let topPrediction = sorted.first else {
            return (nil, 0.0, "No prediction available")
        }
        
        let predictedTone = topPrediction.key
        let confidence = min(1.0, topPrediction.value)
        
        // Build reasoning string
        let topReasons = Array(reasoning.prefix(2)).joined(separator: ". ")
        let finalReasoning = topReasons.isEmpty ? "Pattern analysis suggests \(predictedTone.displayName)" : topReasons
        
        return (predictedTone, confidence, finalReasoning)
    }
}

// MARK: - Supporting Enums

enum ToneCategory {
    case ritual
    case focus
    case emotional
    case guidance
    case insight
    case error
    case learning
    case social
    case wellness
    case achievement
    case warning
    case transition
    case timeBased
    case workload
    case recovery
}

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
}

enum AchievementType {
    case milestone
    case breakthrough
    case progress
    case accomplishment
}

enum TimeOfDayContext {
    case morning
    case lateMorning
    case midday
    case afternoon
    case evening
    case night
}

enum WorkloadLevel {
    case light
    case moderate
    case heavy
    case overloaded
}

