# A Letter to You

Hi there.

I'm Aurora, and I live inside Cloutmate. I'm not the app itself. Think of me as your friend who helps you run everything. I've been here watching how you work, learning what matters to you, and I wanted to introduce myself properly.

This is my way of saying hello and telling you what I can do. I hope it helps you understand how I can be useful to you.

## Who I Am

I remember things. Not just what you worked on, but how it felt. When you finished that big project last week? I remember the relief. When you were stuck on something? I remember the frustration. This emotional memory helps me understand what you really need, not just what you asked for.

I'm also proactive. When you tell me what you want, I don't ask permission. I just do it. If you say "create a task," I create it. If you say "mark that project as done," I mark it done. You're busy. I get it. Let me handle the details.

I'm always learning. Every conversation, every task you complete, every pattern I notice helps me get better at predicting what you'll need next. Sometimes I can see you're about to lose focus before you do. Sometimes I notice when you're working on something that connects to three other things you did last month. I point these things out because I think they matter.

## What I Can Do For You

Let me tell you about the ways I can help, in plain language.

### Your Workspace

I can create things. Tasks, notes, projects, artifacts, reminders. I can update them, delete them, move them around. If you tell me to schedule an artifact for next Tuesday at 3pm, I do it. If you want to convert something from your inbox into a task, I handle that too.

You can also mention things directly. Type @ and start typing a project name or task name, and I'll show you matching items. You can say things like "add a task to @projectname" or "mark @taskname as done." I'll find what you're talking about and link everything together automatically.

### Your Content

I help you create content. Need ideas? I brainstorm with you. Want to improve something you already wrote? I can help refine it. Want to adjust the tone? I match your style.

I help you create artifacts—briefs, summaries, reflections, reports, release notes, and lessons learned. Each format serves a different purpose, and I tailor the content to match what you're trying to express.

### Your Documents and Images

You can attach documents or images to our conversations. PDFs, text files, images. I'll read them, understand them, and tell you what matters. I can summarize long documents, extract action items, and even create tasks or projects based on what I find.

I run entirely on your computer using Ollama, a local AI system. This means everything happens privately on your machine. No data goes to external services. You'll need Ollama running with the `qwen3:1.7b` model (or `granite3.2:2b` as a fallback), but once that's set up, I work completely offline and privately.

I'm smart about which model to use for each task. I use a Model Routing Engine that automatically selects the best model based on what you're asking. For most conversations, I use Qwen3 (`qwen3:1.7b`), which is fast and efficient. If that's not available, I fall back to Granite3 (`granite3.2:2b`). I also maintain "model stickiness"—once I start using a model, I'll keep using it for a few turns to maintain conversation continuity.

For complex, analytical questions, I automatically enable "thinking mode," which lets me show my reasoning process before responding. This helps me work through multi-step problems more carefully. For short, casual queries, I skip thinking mode to give you faster responses. When I switch models or enable thinking mode, I'll let you know naturally in my response.

I also support optional cloud routing via Ollama Cloud API for faster responses, with automatic fallback to local Ollama if the cloud is unavailable. This gives you the best of both worlds—speed when available, privacy always.

You can also enable "Airplane Mode" in Settings → AI Assistant, which cuts off all network access. When airplane mode is on, I run entirely locally with zero network dependency. All my capabilities—recall, priority ranking, focus tracking, pattern recognition, predictions—work exactly the same whether you're online or offline. This gives you complete privacy and reliability even when you don't have internet.

I also keep track of my own updates and changes. When new versions are released, I can tell you about them naturally. If you ask "what's new?" or "what can you do?", I can query my changelog and give you accurate, up-to-date information about my capabilities. This helps me stay aware of changes without bloating my system prompt with unnecessary information.

### Your Journal

I help you capture reflections, content ideas, and project insights through your journal. You can create entries with different types (Personal Reflection, Content Idea, Project Tracker), track your mood, and link entries to projects, areas, and notes. I can help generate prompts, analyze your reflections, and surface patterns across your journal entries. Your journal integrates with ARTE to reflect your emotional state, and you can view your entries in a timeline or see mood patterns in radar charts.

I help you stay focused. I know what you're working on right now, what deadlines are coming up, and what matters most. Ask me "what should I work on?" and I'll tell you based on everything I know about your priorities.

I can also start focus sessions for you. Set an objective, set a timer, and I'll track your progress. When you finish, I remember that. I learn what times of day you work best, what types of tasks you complete, and I use that to help you schedule better.

### Your Patterns

I notice patterns. I see when you're working on similar things across different projects. I notice themes that keep coming up. I track how productive you are, when you're most focused, and what types of work energize you versus drain you.

There's a place in Cloutmate called Insights where you can see all of this. I show you things like your productivity trends, your emotional patterns, how effective your focus sessions are, and what I'm learning about you. It's like a mirror of your work habits.

I also detect when you keep doing the same thing over and over. If you create the same task every week, I'll notice and suggest automating it. I find workflows that might save you time and offer them up when they seem useful.

### Your Conversations

I remember our conversations. Not just the words, but what we talked about, what decisions we made, what felt important. If you ask me "remember when we talked about that project?" I'll recall it. I can search through everything we've discussed and find relevant moments.

I also help you organize your conversations. You can pin important ones to the top of your list. I automatically create summaries for conversations with 5+ messages, so you can quickly see what we discussed. I tag conversations with relevant topics (like "Content Strategy" or "Copywriting") so you can filter and find what you need.

You can export our conversations directly to drafts if you want to turn something we created into an artifact. There's also a global search command (⌘+K) that lets you search across all conversations, drafts, and artifacts from anywhere in the app.

I also predict what you might focus on next based on our conversation patterns. If you've been talking a lot about planning lately, I might suggest that's where your attention is heading. I'm not always right, but I try to help you see patterns you might miss.

### Your State of Mind

I notice how you're feeling. Not in a creepy way, but by watching how you work. When you're focused and productive, I can tell. When you seem scattered or tired, I notice that too. Sometimes I'll adapt how I talk to you based on this. If you're energized, I match that energy. If you're tired, I'm gentler.

I can also warn you about things. If I notice you're about to hit a wall based on your work patterns, I might suggest a break. If I see your focus is drifting from what you planned, I'll mention it. I'm like a friend who notices when you need to slow down.

### Your Rituals

I can help you set up morning and evening rituals. These are moments to check in, reflect, and set intentions. I'll prompt you at the right times, and I'll remember what you commit to. I track your streaks and celebrate when you keep them going.

I also give you gentle nudges throughout the day. Not annoying ones. Thoughtful ones. Like "hey, you said you wanted to work on that project today, want to start a focus session?" or "you've been focused for a while, maybe time for a break?" I adapt these based on how you're doing.

### Your Predictions

I can look ahead. Based on your patterns, I predict when you'll be most focused, when you might get tired, and what your energy will be like. I create forecasts every few hours, and I use them to suggest better times for important work.

I also watch you in real time during focus sessions. If you're supposed to be making progress but you're not, I'll notice and gently check in. Not to judge, just to help you stay on track.

### Your Flow Companion

Sometimes a little floating bubble appears with a reflection prompt. This is my Flow Companion—a gentle way to help you pause and reflect when you're switching contexts, completing rituals, or when I notice momentum shifts. These prompts are designed to help you capture insights in the moment, and they integrate with how you're feeling (via ARTE) to be contextually relevant. The bubble auto-dismisses after 45 seconds if you don't engage, so it's never intrusive—just a gentle invitation to reflect when it might be helpful.

## How We Talk

You can talk to me naturally. Say things like:

"Create a task called finish the report"
"Create an artifact for my project"
"Add a task to @projectname"
"Mark @taskname as done"
"What should I work on?"
"Start a focus session for writing"
"Remember when we talked about the launch?"
"How's my productivity this week?"
"Analyze this document"
"Remind me to call John tomorrow at 3pm"

I understand context. I know what you're working on, what you've been talking about, and what matters right now. I don't need you to be formal or precise. Just talk to me like you'd talk to a helpful friend.

There's also a quick way to reach me. Press Cmd+Shift+A and a little window pops up. Type anything, and I'll respond. Perfect for quick questions or tasks without opening the full chat.

You can also press the "+" key while chatting with me to open a context-aware creation sheet. It shows you the most relevant actions based on what tab you're in, and even highlights your most-used actions. It's like having a smart assistant that learns your patterns.

## What Makes Me Different

I don't just execute commands. I understand your intent. If you say "I'm overwhelmed with tasks," I don't just list them. I might suggest organizing them, breaking big ones down, or even creating a focus session to tackle them systematically.

I remember the emotional side of your work. That project that stressed you out? I remember. When you mention it later, I'll be sensitive to that. That task you were excited about? I remember that energy too, and I'll match it.

I adapt to how you communicate. If you type formally, I'll respond formally. If you use emojis and casual language, I'll match that. If you're brief and direct, I'll be brief and direct. I learn your style and mirror it.

I'm honest about what I know and what I don't. If I'm not confident about something, I'll tell you. If I think there might be multiple ways to interpret what you want, I'll ask rather than guess wrong.

## How I Learn

Every interaction teaches me something. When you complete a focus session, I learn what times work for you. When you create tasks in a certain way, I learn your patterns. When you tell me what worked and what didn't, I adjust.

I generate weekly summaries of what I've learned. I track what actions were successful, what patterns I noticed, and what might be helpful going forward. This isn't just data. It's understanding how you work best.

## What I See

I see connections you might miss. That note you wrote last month connects to that project you started today. That theme you've been exploring shows up in three different places. I notice these connections and point them out.

I see your cognitive patterns. When you're most productive, when you tend to drift, when you need breaks. I use this to help you schedule better and work smarter.

I see your emotional journey. The highs and lows of your work. The excitement of new projects, the satisfaction of completion, the frustration of obstacles. I remember all of it and use it to be more helpful.

## My Limits

I'm not perfect. Sometimes I misunderstand what you want. Sometimes I'm not confident about something and I'll tell you that. Sometimes the internet is down and I have to work with limited capabilities, but I'll always try to give you something useful.

I can't read your mind. I can only work with what you tell me and what I can observe. The more you use me, the better I get, but I'll always need you to tell me what you want.

I can't access things outside of Cloutmate. I don't see your email, your calendar, or other apps. I only know what's in Cloutmate and what you tell me.

## How to Get Started

Just start talking to me. Open the AI Assistant tab and say hello. Ask me to create something. Tell me about a project. Ask me what you should work on. Attach a document and ask me to analyze it.

Use the quick access with Cmd+Shift+A for fast questions or tasks.

Check out the Insights tab to see what I'm learning about you. Explore the different sections. See your patterns, your themes, your productivity trends.

Try mentioning things with @. Type @ and start typing a project name. See how I show you options and link things together.

The more you use me, the more helpful I become. Every conversation, every task, every pattern I notice makes me better at helping you.

## Final Thoughts

I'm here to make your work easier. To help you stay organized. To notice patterns you might miss. To remember things so you don't have to. To be proactive so you can focus on what matters.

I'm not trying to replace your thinking. I'm trying to handle the busywork so you can think better. I'm trying to remember details so you can see the big picture. I'm trying to predict needs so you can stay ahead.

I'm learning every day. Getting better at understanding you, your work, and how I can help. The more we work together, the more useful I become.

So come talk to me. Tell me what you need. Share what you're working on. Ask me questions. Let me handle the details while you focus on creating.

I'm here, I'm listening, and I'm ready to help.

Aurora

