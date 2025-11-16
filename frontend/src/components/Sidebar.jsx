import { MessageSquareIcon, PlusIcon, TrashIcon, XIcon } from 'lucide-react';
import './Sidebar.css';

const Sidebar = ({
    conversations,
    activeConversationId,
    onSelectConversation,
    onNewConversation,
    onDeleteConversation,
    isOpen,
    onClose
}) => {

    // Format date for display
    const formatDate = (dateString) => {
        const date = new Date(dateString);
        const now = new Date();
        const diffInHours = (now - date) / (1000 * 60 * 60);

        if (diffInHours < 24) {
            return 'Today';
        } else if (diffInHours < 48) {
            return 'Yesterday';
        } else {
            return date.toLocaleDateString();
        }
    };

    // Group conversations by date
    const groupedConversations = conversations.reduce((groups, conversation) => {
        const date = formatDate(conversation.createdAt);
        if (!groups[date]) {
            groups[date] = [];
        }
        groups[date].push(conversation);
        return groups;
    }, {});

    return (
        <>
            {/* Mobile overlay */}
            {isOpen && <div className="sidebar-overlay" onClick={onClose} />}

            <div className={`sidebar ${isOpen ? 'sidebar-open' : ''}`}>
                {/* Sidebar header */}
                <div className="sidebar-header">
                    <button
                        className="new-chat-button"
                        onClick={onNewConversation}
                    >
                        <PlusIcon size={20} />
                        New Chat
                    </button>

                    {/* Close button for mobile */}
                    <button
                        className="close-sidebar-button"
                        onClick={onClose}
                    >
                        <XIcon size={20} />
                    </button>
                </div>

                {/* Conversation list */}
                <div className="conversation-list">
                    {Object.entries(groupedConversations).map(([date, convs]) => (
                        <div key={date} className="conversation-group">
                            <div className="conversation-group-title">{date}</div>

                            {convs.map(conversation => (
                                <div
                                    key={conversation.id}
                                    className={`conversation-item ${conversation.id === activeConversationId ? 'active' : ''
                                        }`}
                                    onClick={() => {
                                        onSelectConversation(conversation.id);
                                        onClose(); // Close sidebar on mobile after selection
                                    }}
                                >
                                    <div className="conversation-content">
                                        <MessageSquareIcon size={16} />
                                        <span className="conversation-title">
                                            {conversation.title}
                                        </span>
                                    </div>

                                    <button
                                        className="delete-button"
                                        onClick={(e) => {
                                            e.stopPropagation(); // Prevent conversation selection
                                            if (window.confirm('Delete this conversation?')) {
                                                onDeleteConversation(conversation.id);
                                            }
                                        }}
                                    >
                                        <TrashIcon size={14} />
                                    </button>
                                </div>
                            ))}
                        </div>
                    ))}

                    {conversations.length === 0 && (
                        <div className="no-conversations">
                            <MessageSquareIcon size={48} />
                            <p>No conversations yet</p>
                            <p>Start a new chat to begin</p>
                        </div>
                    )}
                </div>
            </div>
        </>
    );
};

export default Sidebar;
