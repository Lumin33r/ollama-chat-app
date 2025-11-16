import { useEffect, useState } from 'react';
import './App.css';
import ChatInterface from './components/ChatInterface';
import Sidebar from './components/Sidebar';

function App() {
  // State to manage all chat conversations
  const [conversations, setConversations] = useState([]);

  // State to track which conversation is currently active
  const [activeConversationId, setActiveConversationId] = useState(null);

  // State to control sidebar visibility on mobile
  const [sidebarOpen, setSidebarOpen] = useState(false);

  // Load conversations from localStorage when app starts
  useEffect(() => {
    const savedConversations = localStorage.getItem('ollama-conversations');
    if (savedConversations) {
      const parsed = JSON.parse(savedConversations);
      setConversations(parsed);

      // Set the most recent conversation as active
      if (parsed.length > 0) {
        setActiveConversationId(parsed[0].id);
      }
    }
  }, []);

  // Save conversations to localStorage whenever they change
  useEffect(() => {
    if (conversations.length > 0) {
      localStorage.setItem('ollama-conversations', JSON.stringify(conversations));
    }
  }, [conversations]);

  // Create a new conversation
  const createNewConversation = () => {
    const newConversation = {
      id: Date.now().toString(), // Simple ID generation
      title: 'New Chat',
      messages: [],
      createdAt: new Date().toISOString()
    };

    // Add new conversation to the beginning of the list
    setConversations(prev => [newConversation, ...prev]);
    setActiveConversationId(newConversation.id);
    setSidebarOpen(false); // Close sidebar on mobile
  };

  // Delete a conversation
  const deleteConversation = (conversationId) => {
    const updatedConversations = conversations.filter(conv => conv.id !== conversationId);
    setConversations(updatedConversations);

    // If we deleted the active conversation, switch to another one
    if (conversationId === activeConversationId) {
      if (updatedConversations.length > 0) {
        setActiveConversationId(updatedConversations[0].id);
      } else {
        setActiveConversationId(null);
      }
    }
  };

  // Add a message to the active conversation
  const addMessage = (message) => {
    setConversations(prev => prev.map(conv => {
      if (conv.id === activeConversationId) {
        const updatedMessages = [...conv.messages, message];

        // Update conversation title with first user message
        let updatedTitle = conv.title;
        if (conv.title === 'New Chat' && message.role === 'user') {
          updatedTitle = message.content.substring(0, 30) +
            (message.content.length > 30 ? '...' : '');
        }

        return {
          ...conv,
          messages: updatedMessages,
          title: updatedTitle,
          updatedAt: new Date().toISOString()
        };
      }
      return conv;
    }));
  };

  // Get the currently active conversation
  const activeConversation = conversations.find(conv => conv.id === activeConversationId);

  return (
    <div className="app">
      {/* Sidebar for conversation history */}
      <Sidebar
        conversations={conversations}
        activeConversationId={activeConversationId}
        onSelectConversation={setActiveConversationId}
        onNewConversation={createNewConversation}
        onDeleteConversation={deleteConversation}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />

      {/* Main chat interface */}
      <ChatInterface
        conversation={activeConversation}
        onAddMessage={addMessage}
        onNewConversation={createNewConversation}
        onToggleSidebar={() => setSidebarOpen(!sidebarOpen)}
      />
    </div>
  );
}

export default App;
