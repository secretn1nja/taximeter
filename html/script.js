document.addEventListener('DOMContentLoaded', () => {
    let running = false;
    let fare = 0.0;
    let distance = 0.0;
    const fareRate = 1.5;

    const fareDisplay = document.getElementById('fare');
    const distanceDisplay = document.getElementById('distance');
    const historyModal = document.getElementById('historyModal');
    const historyList = document.getElementById('historyList');

    let rideHistory = [];

    const buttons = {
        start: document.getElementById('start'),
        pause: document.getElementById('pause'),
        reset: document.getElementById('reset'),
        close: document.getElementById('close'),
    };

    function startMeter() {
        if (running) return;
        running = true;

        const interval = setInterval(() => {
            if (!running) {
                clearInterval(interval);
            } else {
                distance += 0.1;
                fare = distance * fareRate;
                updateDisplay();
            }
        }, 1000);
    }

    function pauseMeter() {
        running = false;
    }

    function resetMeter() {
        pauseMeter();
        addRideToHistory();
        fare = 0.0;
        distance = 0.0;
        updateDisplay();
    }

    function closeApp() {
        fetch(`https://${GetParentResourceName()}/close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        });
    }

    function updateDisplay() {
        fareDisplay.innerText = `Fare: $${fare.toFixed(2)}`;
        distanceDisplay.innerText = `Distance: ${distance.toFixed(1)} m`;
    }

    function addRideToHistory() {
        if (fare > 0 && distance > 0) {
            if (rideHistory.length >= 10) rideHistory.shift();
            rideHistory.push({ fare, distance });
            updateHistoryDisplay();
        }
    }

    function updateHistoryDisplay() {
        historyList.innerHTML = '';
        rideHistory.forEach(({ fare, distance }) => {
            const listItem = document.createElement('li');
            listItem.innerText = `Fare: $${fare.toFixed(2)}, Distance: ${distance.toFixed(1)} m`;
            historyList.appendChild(listItem);
        });
    }

    window.addEventListener('message', ({ data }) => {
        switch (data.type) {
            case 'ui':
                document.body.style.display = data.status ? 'flex' : 'none';
                break;
            case 'update':
                fareDisplay.innerText = `Fare: $${data.fare.toFixed(2)}`;
                distanceDisplay.innerText = `Distance: ${data.distance.toFixed(1)} m`;
                break;
            case 'role':
                toggleDriverButtons(data.isDriver);
                break;
            case 'updateHistory':
                rideHistory = data.history;
                updateHistoryDisplay();
                break;
            case 'historyUI':
                historyModal.style.display = data.status ? 'flex' : 'none';
                break;
        }
    });

    function toggleDriverButtons(isDriver) {
        const driverButtons = document.querySelector('.buttons.driver-only');
        driverButtons.classList.toggle('hidden', !isDriver);
    }

    let isStartActive = false;
    let isResetActive = false;

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'setActive' || data.action === 'removeActive') {
            const button = document.getElementById(data.button);
            if (!button) return;

            const active = data.action === 'setActive';
            button.classList.toggle('active', active);

            if (data.button === 'start') isStartActive = active;
            if (data.button === 'reset') isResetActive = active;
        }
    });

    function resetButtons() {
        if (isStartActive) toggleButtonState('start', false);
        if (isResetActive) toggleButtonState('reset', true);
    }

    function toggleButtonState(buttonId, active) {
        const action = active ? 'setActive' : 'removeActive';
        SendNUIMessage({ action, button: buttonId });
    }
});
