document.addEventListener('DOMContentLoaded', function () {
    let running = false;
    let fare = 0.0;
    let distance = 0.0;
    const fareRate = 1.5;

    const fareDisplay = document.getElementById('fare');
    const distanceDisplay = document.getElementById('distance');

    const historyModal = document.getElementById('historyModal');
    const historyList = document.getElementById('historyList');

    let rideHistory = [];

    document.getElementById('start').addEventListener('click', () => {
        if (!running) {
            running = true;
            startTaxiMeter();
        }
    });

    document.getElementById('pause').addEventListener('click', () => {
        running = false;
    });

    document.getElementById('reset').addEventListener('click', () => {
        running = false;
        fare = 0.0;
        distance = 0.0;
        updateDisplay();
    });

    document.getElementById('close').addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/close`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({})
        });
    });

    function startTaxiMeter() {
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

    function updateDisplay() {
        fareDisplay.innerText = `Fare: $${fare.toFixed(2)}`;
        distanceDisplay.innerText = `Distance: ${distance.toFixed(1)} m`;
    }

    function addRideToHistory() {
        if (rideHistory.length >= 10) {
            rideHistory.shift();
        }
        rideHistory.push({
            fare: fare,
            distance: distance,
        });
    }

    function updateHistoryDisplay() {
        historyList.innerHTML = '';
        rideHistory.forEach(ride => {
            const listItem = document.createElement('li');
            listItem.innerText = `Fare: $${ride.fare.toFixed(2)}, Distance: ${ride.distance.toFixed(1)} m`;
            historyList.appendChild(listItem);
        });
    }


    window.addEventListener('message', (event) => {
        const data = event.data;

        if (data.type === 'ui') {
            if (data.status) {
                document.body.style.display = "flex";
            } else {
                document.body.style.display = "none";
            }
        }

        if (data.type === 'update') {
            fareDisplay.innerText = `Fare: $${data.fare.toFixed(2)}`;
            distanceDisplay.innerText = `Distance: ${data.distance.toFixed(1)} m`;
        }

        if (data.type === 'updateHistory') {
            rideHistory = data.history;
            updateHistoryDisplay();
        }

        if (data.type === 'historyUI') {
            if (data.status) {
                historyModal.style.display = "flex";
            } else {
                historyModal.style.display = "none";
            }
        }
    });

    function toggleHistoryDisplay() {
        fetch(`https://${GetParentResourceName()}/toggleHistory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }

});

let isStartActive = false;
let isResetActive = false;  

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'setActive') {
        const button = document.getElementById(data.button);
        if (button) {
            button.classList.add('active');
            if (data.button === 'start') {
                isStartActive = true;
            } else if (data.button === 'reset') {
                isResetActive = true;
            }
        }
    }

    if (data.action === 'removeActive') {
        const button = document.getElementById(data.button);
        if (button) {
            button.classList.remove('active');
            if (data.button === 'start') {
                isStartActive = false;
            } else if (data.button === 'reset') {
                isResetActive = false;
            }
        }
    }
});

function resetButtons() {
    if (isStartActive) {
        SendNUIMessage({ action: 'removeActive', button: 'start' });
    }
    if (isResetActive) {
        SendNUIMessage({ action: 'setActive', button: 'reset' });
    }
}