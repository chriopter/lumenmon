// Agent table component with TUI styling and row selection
// Handles rendering and visual updates for the agent list

let selectedRow = 0;
let agentsData = [];

function renderTable(agents) {
    agentsData = agents;
    const container = document.getElementById('agents-container');

    if (!agents || agents.length === 0) {
        container.innerHTML = '<div class="no-data">no agents connected</div>';
        selectedRow = 0;
        return;
    }

    let html = `
        <table id="agents-table">
            <thead>
                <tr>
                    <td>id</td>
                    <td>status</td>
                    <td>cpu</td>
                    <td>mem</td>
                    <td>disk</td>
                    <td>age</td>
                </tr>
            </thead>
            <tbody>
    `;

    agents.forEach((agent, index) => {
        const age = formatAge(agent.age);
        const cpuSparkline = generateSparkline(agent.cpuHistory || []);
        const memSparkline = generateSparkline(agent.memHistory || []);
        const diskSparkline = generateSparkline(agent.diskHistory || []);
        const isSelected = index === selectedRow;

        html += `
            <tr class="agent-row ${isSelected ? 'selected' : ''}" data-index="${index}" data-agent-id="${agent.id}">
                <td>${agent.id}</td>
                <td><span is-="badge" class="badge-${agent.status}">${agent.status}</span></td>
                <td>${agent.cpu.toFixed(1)}% ${cpuSparkline}</td>
                <td>${agent.memory.toFixed(1)}% ${memSparkline}</td>
                <td>${agent.disk.toFixed(1)}% ${diskSparkline}</td>
                <td>${age}</td>
            </tr>
        `;
    });

    html += '</tbody></table>';
    container.innerHTML = html;

    // Add click handlers
    document.querySelectorAll('.agent-row').forEach(row => {
        row.addEventListener('click', () => {
            const index = parseInt(row.dataset.index);
            selectRow(index);
        });
    });
}

function selectRow(index) {
    if (index < 0 || index >= agentsData.length) return;

    selectedRow = index;

    // Update visual selection
    document.querySelectorAll('.agent-row').forEach((row, i) => {
        if (i === index) {
            row.classList.add('selected');
        } else {
            row.classList.remove('selected');
        }
    });
}

function moveSelection(direction) {
    if (agentsData.length === 0) return;

    const newIndex = selectedRow + direction;
    if (newIndex >= 0 && newIndex < agentsData.length) {
        selectRow(newIndex);

        // Scroll into view
        const row = document.querySelector(`.agent-row[data-index="${newIndex}"]`);
        if (row) {
            row.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }
}

function getSelectedAgent() {
    return agentsData[selectedRow] || null;
}

function generateSparkline(values, width = 50, height = 20) {
    if (!values || values.length === 0) {
        return '';
    }

    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min || 1;

    const points = values.map((val, i) => {
        const x = (i / (values.length - 1 || 1)) * width;
        const y = height - ((val - min) / range) * height;
        return `${x},${y}`;
    }).join(' ');

    return `<svg width="${width}" height="${height}" class="sparkline">
        <polyline
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            points="${points}"
        />
    </svg>`;
}

function formatAge(seconds) {
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`;
    return `${Math.floor(seconds / 86400)}d`;
}
