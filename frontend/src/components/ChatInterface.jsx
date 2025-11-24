import { BotIcon, MenuIcon, SendIcon, UserIcon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import api from '../services/api';
import './ChatInterface.css';

const ChatInterface = ({
    conversation,
    onAddMessage,
    onNewConversation,
    onToggleSidebar
}) => {
    // State for the current message being typed
    const [inputMessage, setInputMessage] = useState('');

    // State to track if we're waiting for AI response
    const [isLoading, setIsLoading] = useState(false);

    // Ref to auto-scroll to bottom of messages
    const messagesEndRef = useRef(null);

    // Ref for the input textarea
    const inputRef = useRef(null);

    // Auto-scroll to bottom when new messages arrive
    useEffect(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [conversation?.messages]);

    // Focus input when conversation changes
    useEffect(() => {
        inputRef.current?.focus();
    }, [conversation?.id]);

    // Handle sending a message
    const handleSendMessage = async () => {
        // Don't send empty messages or while loading
        if (!inputMessage.trim() || isLoading) return;

        // If no conversation exists, create one
        if (!conversation) {
            onNewConversation();
            return;
        }

        const userMessage = {
            id: Date.now().toString(),
            role: 'user',
            content: inputMessage.trim(),
            timestamp: new Date().toISOString()
        };

        // Add user message immediately
        onAddMessage(userMessage);

        // Clear input and show loading
        setInputMessage('');
        setIsLoading(true);

        try {
            // Call backend API using the api service
            const response = await api.post('/api/chat', {
                prompt: userMessage.content,
                model: 'llama2', // Add model parameter
                conversation_id: conversation.id,
                // Include conversation history for context
                messages: conversation.messages.map(msg => ({
                    role: msg.role,
                    content: msg.content
                }))
            });

            // Add AI response
            const aiMessage = {
                id: (Date.now() + 1).toString(),
                role: 'assistant',
                content: response.data.response,
                timestamp: new Date().toISOString()
            };

            onAddMessage(aiMessage);

        } catch (error) {
            console.error('Error sending message:', error);

            // Show detailed error message
            const errorContent = error.response?.data?.error
                || error.message
                || 'Sorry, I encountered an error. Please try again.';

            // Add error message
            const errorMessage = {
                id: (Date.now() + 1).toString(),
                role: 'assistant',
                content: errorContent,
                timestamp: new Date().toISOString(),
                isError: true
            };

            onAddMessage(errorMessage);
        } finally {
            setIsLoading(false);
        }
    };

    // Handle Enter key press
    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSendMessage();
        }
    };

    // Render individual message
    const renderMessage = (message) => (
        <div
            key={message.id}
            className={`message ${message.role} ${message.isError ? 'error' : ''}`}
        >
            <div className="message-avatar">
                {message.role === 'user' ? (
                    <UserIcon size={20} />
                ) : (
                    <BotIcon size={20} />
                )}
            </div>

            <div className="message-content">
                <div className="message-text">
                    {message.content}
                </div>
                <div className="message-time">
                    {new Date(message.timestamp).toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit'
                    })}
                </div>
            </div>
        </div>
    );

    return (
        <div className="chat-interface">
            {/* Header */}
            <div className="chat-header">
                <button
                    className="menu-button"
                    onClick={onToggleSidebar}
                >
                    <MenuIcon size={20} />
                </button>

                <div className="chat-title">
                    {conversation ? conversation.title : 'Ollama Chat'}
                </div>

                <button
                    className="new-chat-header-button"
                    onClick={onNewConversation}
                >
                    New Chat
                </button>
            </div>

            {/* Messages Area */}
            <div className="messages-container">
                {conversation && conversation.messages.length > 0 ? (
                    <div className="messages">
                        {conversation.messages.map(renderMessage)}
                        {isLoading && (
                            <div className="message assistant loading">
                                <div className="message-avatar">
                                    <BotIcon size={20} />
                                </div>
                                <div className="message-content">
                                    <div className="typing-indicator">
                                        <span></span>
                                        <span></span>
                                        <span></span>
                                    </div>
                                </div>
                            </div>
                        )}
                        <div ref={messagesEndRef} />
                    </div>
                ) : (
                    <div className="welcome-screen">
                        <div className="welcome-content">
                            <BotIcon size={64} />
                            <h2>Welcome to Ollama Chat</h2>
                            <p>Start a conversation by typing a message below.</p>
                            <div className="example-prompts">
                                <button
                                    className="example-prompt"
                                    onClick={() => setInputMessage("What can you help me with?")}
                                >
                                    What can you help me with?
                                </button>
                                <button
                                    className="example-prompt"
                                    onClick={() => setInputMessage("Explain quantum computing")}
                                >
                                    Explain quantum computing
                                </button>
                                <button
                                    className="example-prompt"
                                    onClick={() => setInputMessage("Write a Python function")}
                                >
                                    Write a Python function
                                </button>
                            </div>
                        </div>
                    </div>
                )}
            </div>

            {/* Input Area */}
            <div className="input-container">
                <div className="input-wrapper">
                    <textarea
                        ref={inputRef}
                        value={inputMessage}
                        onChange={(e) => setInputMessage(e.target.value)}
                        onKeyPress={handleKeyPress}
                        placeholder="Type a message..."
                        disabled={isLoading}
                        rows={1}
                        className="message-input"
                    />

                    <button
                        onClick={handleSendMessage}
                        disabled={!inputMessage.trim() || isLoading}
                        className="send-button"
                    >
                        <SendIcon size={20} />
                    </button>
                </div>

                <div className="input-footer">
                    Ollama Chat can make mistakes. Consider checking important information.
                </div>
            </div>
        </div>
    );
};

export default ChatInterface;
