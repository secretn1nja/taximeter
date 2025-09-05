document.addEventListener('DOMContentLoaded', () => {
    // Application state
    let appState = {
        running: false,
        fare: 0.0,
        distance: 0.0,
        isDriver: false,
        rideHistory: []
    };

    // DOM elements
    const elements = {
        fareDisplay: document.getElementById('fare'),
        distanceDisplay: document.getElementById('distance'),
        historyModal: document.getElementById('historyModal'),
        historyList: document.getElementById('historyList'),
        statusIndicator: document.getElementById('statusIndicator'),
        emptyState: document.getElementById('emptyState'),
        modalBackdrop: document.getElementById('modalBackdrop'),
        modalClose: document.getElementById('modalClose'),
        buttons: {
            start: document.getElementById('start'),
            pause: document.getElementById('pause'),
            reset: document.getElementById('reset'),
            close: document.getElementById('close')
        }
    };

    // Utility functions
    const formatCurrency = (amount) => `$${amount.toFixed(2)}`;
    const formatDistance = (distance) => `${distance.toFixed(1)} m`;
    const formatTime = (timestamp) => {
        const date = new Date(timestamp * 1000);
        return date.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: false 
        });
    };

    // Status management
    const updateStatus = (status, color = '#28a745') => {
        const statusText = elements.statusIndicator.querySelector('.status-text');
        const statusDot = elements.statusIndicator.querySelector('.status-dot');
        
        statusText.textContent = status;
        statusDot.style.background = color;
        statusDot.style.boxShadow = `0 0 8px ${color}50`;
    };

    // Display updates
    const updateDisplay = (fare = appState.fare, distance = appState.distance) => {
        elements.fareDisplay.textContent = formatCurrency(fare);
        elements.distanceDisplay.textContent = formatDistance(distance);
        
        // Update app state
        appState.fare = fare;
        appState.distance = distance;
        
        // Update status based on values
        if (fare > 0 || distance > 0) {
            if (appState.running) {
                updateStatus('RUNNING', '#ffc107');
            } else {
                updateStatus('PAUSED', '#17a2b8');
            }
        } else {
            updateStatus('READY', '#28a745');
        }
    };

    // Button state management
    const setButtonActive = (buttonId, active) => {
        const button = elements.buttons[buttonId];
        if (button) {
            button.classList.toggle('active', active);
        }
    };

    const resetAllButtons = () => {
        Object.keys(elements.buttons).forEach(buttonId => {
            if (buttonId !== 'close') {
                setButtonActive(buttonId, false);
            }
        });
    };

    // History management
    const updateHistoryDisplay = () => {
        const historyList = elements.historyList;
        const emptyState = elements.emptyState;
        
        if (!appState.rideHistory || appState.rideHistory.length === 0) {
            historyList.style.display = 'none';
            emptyState.style.display = 'block';
            return;
        }
        
        historyList.style.display = 'flex';
        emptyState.style.display = 'none';
        historyList.innerHTML = '';
        
        // Display rides in reverse order (newest first)
        [...appState.rideHistory].reverse().forEach((ride, index) => {
            const listItem = document.createElement('li');
            listItem.innerHTML = `
                <span class="history-fare">${formatCurrency(ride.fare)}</span>
                <span class="history-distance">${formatDistance(ride.distance)}</span>
                ${ride.timestamp ? `<span class="history-time">${formatTime(ride.timestamp)}</span>` : ''}
            `;
            listItem.style.animationDelay = `${index * 0.1}s`;
            historyList.appendChild(listItem);
        });
    };

    // Driver interface management
    const toggleDriverButtons = (isDriver) => {
        const driverButtons = document.querySelector('.buttons.driver-only');
        if (driverButtons) {
            driverButtons.classList.toggle('hidden', !isDriver);
        }
        appState.isDriver = isDriver;
        
        // Update status text based on role
        if (isDriver) {
            updateStatus('DRIVER', '#ffc107');
        } else {
            updateStatus('PASSENGER', '#17a2b8');
        }
    };

    // Modal management
    const showHistoryModal = () => {
        elements.historyModal.style.display = 'block';
        updateHistoryDisplay();
        
        // Add escape key listener
        document.addEventListener('keydown', handleEscapeKey);
    };

    const hideHistoryModal = () => {
        elements.historyModal.style.display = 'none';
        document.removeEventListener('keydown', handleEscapeKey);
    };

    const handleEscapeKey = (event) => {
        if (event.key === 'Escape') {
            hideHistoryModal();
        }
    };

    // Event listeners
    elements.modalBackdrop?.addEventListener('click', hideHistoryModal);
    elements.modalClose?.addEventListener('click', hideHistoryModal);

    // Button click handlers (for testing/fallback)
    elements.buttons.close?.addEventListener('click', () => {
        try {
            fetch(`https://${GetParentResourceName()}/close`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        } catch (error) {
            console.warn('Could not send close event to game');
        }
    });

    // Message handling from game
    window.addEventListener('message', (event) => {
        const { data } = event;
        
        try {
            switch (data.type) {
                case 'ui':
                    document.body.style.display = data.status ? 'flex' : 'none';
                    if (data.status) {
                        updateDisplay();
                    }
                    break;

                case 'update':
                    updateDisplay(data.fare, data.distance);
                    break;

                case 'role':
                    toggleDriverButtons(data.isDriver);
                    break;

                case 'updateHistory':
                    appState.rideHistory = data.history || [];
                    updateHistoryDisplay();
                    break;

                case 'historyUI':
                    if (data.status) {
                        showHistoryModal();
                    } else {
                        hideHistoryModal();
                    }
                    break;

                default:
                    break;
            }
        } catch (error) {
            console.error('Error handling message:', error);
        }
    });

    // Button action handling from game
    window.addEventListener('message', (event) => {
        const { data } = event;
        
        if (data.action === 'setActive' || data.action === 'removeActive') {
            const active = data.action === 'setActive';
            setButtonActive(data.button, active);
            
            // Update running state based on button states
            if (data.button === 'start') {
                appState.running = active;
            } else if (data.button === 'pause') {
                appState.running = !active;
            }
            
            updateDisplay();
        }
    });

    // Initialize display
    updateDisplay();
    updateStatus('READY');
    
    // Performance optimization: Use RAF for smooth animations
    let animationFrame;
    const smoothUpdate = () => {
        // Any smooth animations or updates can go here
        animationFrame = requestAnimationFrame(smoothUpdate);
    };
    smoothUpdate();
    
    // Cleanup on page unload
    window.addEventListener('beforeunload', () => {
        if (animationFrame) {
            cancelAnimationFrame(animationFrame);
        }
    });

    console.log('🚕 Taximeter Pro initialized successfully');
});
