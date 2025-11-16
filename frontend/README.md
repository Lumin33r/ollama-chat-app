# Ollama Chat App - Frontend

A modern, responsive React frontend for the Ollama Chat application, providing a ChatGPT-like interface for AI conversations.

## 🚀 Overview

This React frontend creates an intuitive chat interface that communicates with a Flask backend to process AI conversations through Ollama. The application features conversation persistence, responsive design, and a clean user experience similar to ChatGPT.

## 📁 Project Structure

```
frontend/
├── README.md                    # This file
├── package.json                 # Dependencies and scripts
├── package-lock.json            # Locked dependency versions
├── vite.config.js              # Vite configuration with API proxy
├── index.html                  # HTML template
├── eslint.config.js            # Linting configuration
├── public/                     # Static assets
├── node_modules/               # Installed dependencies
└── src/                        # Source code
    ├── main.jsx                # React application entry point
    ├── App.jsx                 # Main application component
    ├── App.css                 # Main application styles
    ├── index.css               # Global styles and CSS reset
    └── components/             # Reusable components
        ├── Sidebar.jsx         # Conversation history sidebar
        ├── Sidebar.css         # Sidebar component styles
        ├── ChatInterface.jsx   # Main chat interface
        └── ChatInterface.css   # Chat interface styles
```

## 🔧 File Walkthrough

### Core Application Files

#### `src/main.jsx`
The React application entry point that renders the App component into the DOM:
- Sets up React 18's createRoot for modern rendering
- Imports global styles and main App component
- Provides the mounting point for the entire application

#### `src/App.jsx`
The main application component managing global state and layout:
- **State Management**: Manages conversations, current conversation, and loading states
- **Data Persistence**: Saves/loads conversations from localStorage
- **Component Orchestration**: Renders Sidebar and ChatInterface components
- **API Integration**: Handles conversation creation and management
- **Layout**: Provides the main application structure with responsive design

#### `src/App.css`
Main application styles defining the overall layout:
- **Grid Layout**: Uses CSS Grid for main application structure
- **Responsive Design**: Mobile-first approach with breakpoints
- **Dark Theme**: Professional dark color scheme
- **Typography**: Modern font stack and text styling

### Component Files

#### `src/components/Sidebar.jsx`
Conversation history and management component:
- **Props Interface**: Receives conversations, current conversation, and event handlers
- **Conversation List**: Displays all saved conversations with timestamps
- **Active State**: Highlights currently selected conversation
- **New Chat**: Provides button to start new conversations
- **Responsive**: Collapsible on mobile devices

#### `src/components/Sidebar.css`
Sidebar-specific styling:
- **Fixed Positioning**: Keeps sidebar visible during scrolling
- **Hover Effects**: Interactive states for conversation items
- **Mobile Responsive**: Transforms to overlay on small screens
- **Scrollable Content**: Handles overflow for many conversations

#### `src/components/ChatInterface.jsx`
Main chat interface for message exchange:
- **Message Display**: Renders conversation history with proper formatting
- **Input Handling**: Manages message input with Enter key support
- **API Communication**: Sends messages to Flask backend via axios
- **Loading States**: Shows typing indicators during API calls
- **Auto-scroll**: Automatically scrolls to latest messages
- **Error Handling**: Manages API errors gracefully

#### `src/components/ChatInterface.css`
Chat interface styling with ChatGPT-inspired design:
- **Message Bubbles**: Distinct styling for user and AI messages
- **Smooth Animations**: Loading dots and transitions
- **Responsive Layout**: Adapts to different screen sizes
- **Input Design**: Modern text input with send button
- **Scrollable History**: Proper overflow handling for message history

### Configuration Files

#### `vite.config.js`
Vite build tool configuration:
- **Development Server**: Configures dev server on port 3000
- **API Proxy**: Routes `/api/*` requests to Flask backend on port 5000
- **Hot Reload**: Enables fast refresh during development
- **React Plugin**: Integrates React-specific optimizations

#### `package.json`
Project dependencies and scripts:
- **Dependencies**: React, axios for API calls, lucide-react for icons
- **Dev Dependencies**: Vite, ESLint for code quality
- **Scripts**: Development server, build, preview, and linting commands
- **Configuration**: ES modules, React JSX transform

## 🛠️ Development Setup

### Prerequisites
- Node.js (version 16 or higher)
- npm (comes with Node.js)

### Installation
```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev
```

The application will be available at `http://localhost:3000`

### Development Commands
```bash
npm run dev      # Start development server with hot reload
npm run build    # Build for production
npm run preview  # Preview production build locally
npm run lint     # Run ESLint for code quality
```

## 🐳 Docker Deployment

### Development Container
```dockerfile
FROM node:18-alpine AS development

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host"]
```

### Production Container
```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Build and Run with Docker
```bash
# Build development image
docker build -t ollama-chat-frontend:dev .

# Run development container
docker run -p 3000:3000 ollama-chat-frontend:dev

# Build production image
docker build -t ollama-chat-frontend:prod -f Dockerfile.prod .

# Run production container
docker run -p 80:80 ollama-chat-frontend:prod
```

## 🔌 API Integration

The frontend communicates with the Flask backend through these endpoints:

### POST `/api/chat`
Send a message and receive AI response:
```javascript
const response = await axios.post('/api/chat', {
  message: userMessage,
  conversation_id: currentConversationId
});
```

### Response Format
```json
{
  "response": "AI generated response text",
  "conversation_id": "unique-conversation-identifier"
}
```

## 📱 Features

### ✅ Implemented Features
- **Modern React Architecture**: Functional components with hooks
- **Conversation Persistence**: Automatic save/load from localStorage
- **Responsive Design**: Mobile-first approach that works on all devices
- **Real-time Chat**: Immediate message exchange with loading states
- **ChatGPT-like Interface**: Familiar and intuitive user experience
- **Error Handling**: Graceful handling of network and API errors
- **Accessible Design**: Proper semantic HTML and keyboard navigation

### 🚀 Future Enhancements
- **Message Formatting**: Markdown rendering for code blocks and formatting
- **File Upload**: Support for document and image uploads
- **Export Options**: Export conversations as PDF or text files
- **Theme Switching**: Light/dark theme toggle
- **User Accounts**: Authentication and cloud sync
- **Message Search**: Full-text search across conversation history

## 🔧 Technical Details

### State Management
- Uses React's built-in `useState` and `useEffect` hooks
- Centralizes conversation state in the main App component
- Implements localStorage for client-side persistence

### Styling Approach
- CSS Modules pattern with component-specific styles
- Mobile-first responsive design principles
- CSS Grid and Flexbox for modern layouts
- Custom CSS properties for consistent theming

### Performance Optimizations
- Vite for fast development and optimized builds
- Component-based architecture for code reusability
- Efficient re-rendering through proper dependency arrays
- Lazy loading ready for future route-based code splitting

## 🐛 Troubleshooting

### Common Issues

**Port 3000 already in use:**
```bash
# Kill process using port 3000
lsof -ti:3000 | xargs kill -9

# Or use different port
npm run dev -- --port 3001
```

**API requests failing:**
- Ensure Flask backend is running on port 5000
- Check vite.config.js proxy configuration
- Verify network connectivity between frontend and backend

**Build failures:**
```bash
# Clear npm cache
npm cache clean --force

# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

## 📊 Browser Support

- **Modern Browsers**: Chrome 90+, Firefox 88+, Safari 14+, Edge 90+
- **Mobile**: iOS Safari 14+, Chrome Mobile 90+
- **Features Used**: ES6+ JavaScript, CSS Grid, Flexbox, Fetch API

## 🤝 Contributing

1. Follow the existing code style and component patterns
2. Use semantic commit messages
3. Test on multiple screen sizes and browsers
4. Update documentation for new features
5. Run `npm run lint` before committing

---

*This frontend is part of the complete Ollama Chat App project. See the main project README for full setup instructions including backend and deployment.*
