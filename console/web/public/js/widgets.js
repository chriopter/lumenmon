/**
 * Lumenmon Widget System
 * Modular widgets that mirror agent collector structure.
 * Each widget declares its metrics, type, and render function.
 */

window.LumenmonWidgets = {
    registered: {},
    instances: {},
    expandedWidget: null,
    focusedIndex: -1,

    // Grid size mapping: size -> CSS class (4-column grid)
    // xs=1/4, sm=2/4, md=3/4, lg=4/4 (full)
    gridSizes: {
        'sparkline': 'grid-xs',   // 1/4 width (1 column)
        'stat': 'grid-sm',        // 2/4 width (2 columns)
        'chart': 'grid-lg',       // Full width (4 columns)
        'table': 'grid-lg'        // Full width (4 columns)
    },

    /**
     * Register a widget
     * @param {Object} config - Widget configuration
     * @param {string} config.name - Unique widget name (e.g., 'cpu', 'proxmox_zfs')
     * @param {string} config.title - Display title
     * @param {string} config.category - Category for grouping ('generic', 'proxmox')
     * @param {string[]} config.metrics - Metric patterns this widget handles (supports * wildcard)
     * @param {string} config.size - Widget size: 'sparkline' | 'stat' | 'chart' | 'table'
     * @param {string} config.gridSize - Override grid size: 'sm' | 'md' | 'lg'
     * @param {boolean} config.expandable - Whether widget can expand to show chart (default: true for sparklines)
     * @param {number} config.interval - Refresh interval in ms (default: 1000)
     * @param {Function} config.render - Render function(container, data, agent)
     * @param {Function} config.renderExpanded - Render function for expanded view
     */
    register: function(config) {
        if (!config.name) {
            console.error('Widget missing name:', config);
            return;
        }
        this.registered[config.name] = {
            name: config.name,
            title: config.title || config.name,
            category: config.category || 'generic',
            metrics: config.metrics || [config.name],
            size: config.size || 'stat',
            gridSize: config.gridSize || null,
            priority: config.priority || 50,  // Lower = first (default 50)
            expandable: config.expandable !== undefined ? config.expandable : (config.size === 'sparkline'),
            interval: config.interval || 1000,
            render: config.render || function() {},
            renderExpanded: config.renderExpanded || null,
            init: config.init || null,  // Init function for charts
            initExpanded: config.initExpanded || null,  // Init function for expanded charts
            update: config.update || null  // Optional update function for live refresh
        };
    },

    /**
     * Match metric name against widget patterns
     * @param {string} metricName - Metric name to match
     * @param {string[]} patterns - Patterns to match against (supports * wildcard)
     */
    matchesPattern: function(metricName, patterns) {
        return patterns.some(pattern => {
            if (pattern.includes('*')) {
                const regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
                return regex.test(metricName);
            }
            return metricName === pattern;
        });
    },

    /**
     * Find widgets that match available metrics
     * @param {string[]} metricNames - Available metric names for this agent
     * @returns {Object[]} Matching widgets with their data
     */
    findMatching: function(metricNames) {
        const matched = [];

        for (const [name, widget] of Object.entries(this.registered)) {
            // Widgets with empty metrics array are standalone (e.g., messages widget)
            if (widget.metrics.length === 0) {
                matched.push({
                    widget: widget,
                    metrics: []
                });
                continue;
            }

            const matchingMetrics = metricNames.filter(m =>
                this.matchesPattern(m, widget.metrics)
            );

            if (matchingMetrics.length > 0) {
                matched.push({
                    widget: widget,
                    metrics: matchingMetrics
                });
            }
        }

        return matched;
    },

    /**
     * Render all matching widgets for an agent
     * @param {HTMLElement} container - Container element
     * @param {Object} agent - Agent data with metrics
     * @param {Object[]} tables - Metric tables from API
     */
    renderAll: function(container, agent, tables) {
        const metricNames = tables.map(t => t.metric_name);
        const matched = this.findMatching(metricNames);

        // Clear existing instances and state
        this.instances = {};
        this.expandedWidget = null;
        this.focusedIndex = -1;

        // Sort widgets: by priority first (lower = first), then by size
        const sizeOrder = { 'sparkline': 0, 'stat': 1, 'chart': 2, 'table': 3 };
        matched.sort((a, b) => {
            // Priority first (lower = first)
            if (a.widget.priority !== b.widget.priority) {
                return a.widget.priority - b.widget.priority;
            }
            // Then by size
            return (sizeOrder[a.widget.size] || 99) - (sizeOrder[b.widget.size] || 99);
        });

        // Build unified grid
        let html = '<div class="widget-grid">';
        let widgetIndex = 0;

        matched.forEach(m => {
            const widgetData = this.getWidgetData(m.metrics, tables);
            const gridClass = m.widget.gridSize
                ? `grid-${m.widget.gridSize}`
                : (this.gridSizes[m.widget.size] || 'grid-sm');
            const expandableAttr = m.widget.expandable ? 'data-expandable="true"' : '';
            const tabIndex = m.widget.expandable || m.widget.size === 'sparkline' || m.widget.size === 'stat' ? '0' : '-1';

            html += `<div class="widget widget-${m.widget.size} ${gridClass}" data-widget="${m.widget.name}" data-index="${widgetIndex}" ${expandableAttr} tabindex="${tabIndex}">`;
            html += m.widget.render(widgetData, agent);
            html += '</div>';

            this.instances[m.widget.name] = {
                widget: m.widget,
                metrics: m.metrics,
                index: widgetIndex,
                data: widgetData,
                agent: agent
            };
            widgetIndex++;
        });

        html += '</div>';
        container.innerHTML = html;

        // Attach click/keyboard handlers for expandable widgets
        this.attachWidgetHandlers(container, agent, tables);

        // Initialize any widgets that need it
        matched.forEach(m => {
            if (m.widget.init) {
                const widgetData = this.getWidgetData(m.metrics, tables);
                const el = container.querySelector(`[data-widget="${m.widget.name}"]`);
                if (el) m.widget.init(el, widgetData, agent);
            }
        });

        // Restore expanded widget from localStorage
        try {
            const savedExpanded = localStorage.getItem('lumenmon_expanded_widget');
            if (savedExpanded && this.instances[savedExpanded]) {
                const el = container.querySelector(`[data-widget="${savedExpanded}"]`);
                if (el) {
                    this.expandWidget(el, this.instances[savedExpanded], container, agent, tables);
                }
            }
        } catch (e) { /* localStorage not available */ }
    },

    /**
     * Attach click and keyboard handlers to widgets
     */
    attachWidgetHandlers: function(container, agent, tables) {
        const widgets = container.querySelectorAll('.widget[data-expandable="true"]');
        const self = this;

        widgets.forEach(el => {
            // Click to expand/collapse
            el.addEventListener('click', (e) => {
                if (e.target.classList.contains('tui-collapse-btn')) {
                    self.collapseWidget(container, agent, tables);
                } else {
                    self.toggleWidget(el, container, agent, tables);
                }
            });

            // Keyboard: Enter to expand/collapse
            el.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    self.toggleWidget(el, container, agent, tables);
                } else if (e.key === 'Escape' && self.expandedWidget) {
                    e.preventDefault();
                    e.stopPropagation();
                    self.collapseWidget(container, agent, tables);
                }
            });
        });

        // Widget grid keyboard navigation
        container.addEventListener('keydown', (e) => {
            if (e.target.classList.contains('widget')) {
                const widgetEls = Array.from(container.querySelectorAll('.widget[tabindex="0"]'));
                const currentIndex = widgetEls.indexOf(e.target);

                if (e.key === 'ArrowRight' || e.key === 'l') {
                    e.preventDefault();
                    const next = widgetEls[currentIndex + 1];
                    if (next) next.focus();
                } else if (e.key === 'ArrowLeft' || e.key === 'h') {
                    e.preventDefault();
                    const prev = widgetEls[currentIndex - 1];
                    if (prev) prev.focus();
                } else if (e.key === 'Tab' && !e.shiftKey) {
                    // Let tab work naturally but track focus
                }
            }
        });
    },

    /**
     * Toggle widget expansion
     */
    toggleWidget: function(el, container, agent, tables) {
        const widgetName = el.dataset.widget;
        const instance = this.instances[widgetName];
        if (!instance) return;

        if (this.expandedWidget === widgetName) {
            // Collapse
            this.collapseWidget(container, agent, tables);
        } else {
            // Expand
            this.expandWidget(el, instance, container, agent, tables);
        }
    },

    /**
     * Expand a widget to show full chart
     */
    expandWidget: function(el, instance, container, agent, tables) {
        const widget = instance.widget;
        const widgetData = this.getWidgetData(instance.metrics, tables);

        // Collapse any existing expanded widget first
        if (this.expandedWidget) {
            this.collapseWidget(container, agent, tables);
        }

        this.expandedWidget = widget.name;
        el.classList.add('widget-expanded');

        // Save expanded state to localStorage
        try {
            localStorage.setItem('lumenmon_expanded_widget', widget.name);
        } catch (e) { /* localStorage not available */ }

        // Render expanded view
        if (widget.renderExpanded) {
            el.innerHTML = widget.renderExpanded(widgetData, agent);
        } else {
            // Default expanded view with chart
            const chartId = `chart-${widget.name}-expanded`;
            el.innerHTML = `
                <div class="tui-metric-box">
                    <div class="tui-metric-header">${widget.title}</div>
                    <span class="tui-collapse-btn" title="collapse">esc ×</span>
                    <div class="widget-chart-container">
                        <canvas id="${chartId}"></canvas>
                    </div>
                </div>
            `;

            // Initialize chart if widget has initExpanded
            if (widget.initExpanded) {
                widget.initExpanded(el, widgetData, agent, chartId);
            } else if (widget.init) {
                // Fall back to regular init
                widget.init(el, widgetData, agent);
            }
        }

        el.focus();
    },

    /**
     * Collapse expanded widget
     */
    collapseWidget: function(container, agent, tables) {
        if (!this.expandedWidget) return;

        const el = container.querySelector(`[data-widget="${this.expandedWidget}"]`);
        const instance = this.instances[this.expandedWidget];

        if (el && instance) {
            el.classList.remove('widget-expanded');
            const widgetData = this.getWidgetData(instance.metrics, tables);
            el.innerHTML = instance.widget.render(widgetData, agent);
            el.focus();
        }

        this.expandedWidget = null;

        // Clear expanded state from localStorage
        try {
            localStorage.removeItem('lumenmon_expanded_widget');
        } catch (e) { /* localStorage not available */ }
    },

    /**
     * Update all widgets with new data (for live refresh)
     * @param {HTMLElement} container - Container element
     * @param {Object} agent - Agent data
     * @param {Object[]} tables - Fresh metric tables
     */
    updateAll: function(container, agent, tables) {
        for (const [name, instance] of Object.entries(this.instances)) {
            const el = container.querySelector(`[data-widget="${name}"]`);
            if (!el) continue;

            // Update stored agent data for expand/collapse
            instance.agent = agent;

            const widgetData = this.getWidgetData(instance.metrics, tables);
            instance.data = widgetData;

            // Skip update if this widget is expanded - it has its own chart that doesn't need re-render
            if (this.expandedWidget === name) {
                // Update the expanded chart if widget has initExpanded
                if (instance.widget.initExpanded) {
                    instance.widget.initExpanded(el, widgetData, agent, `chart-${name}-expanded`);
                }
                continue;
            }

            if (instance.widget.update) {
                // Use custom update function if available
                instance.widget.update(el, widgetData, agent);
            } else if (instance.widget.init) {
                // Chart widgets: re-render and re-init
                el.innerHTML = instance.widget.render(widgetData, agent);
                instance.widget.init(el, widgetData, agent);
            } else {
                // Default: re-render entire widget
                el.innerHTML = instance.widget.render(widgetData, agent);
            }
        }
    },

    /**
     * Get data for widget from tables
     * @param {string[]} metricNames - Metrics this widget needs
     * @param {Object[]} tables - All tables from API
     * @returns {Object} Data keyed by metric name
     */
    getWidgetData: function(metricNames, tables) {
        const data = {};
        metricNames.forEach(name => {
            const table = tables.find(t => t.metric_name === name);
            if (table) {
                data[name] = table;
            }
        });
        return data;
    },

    /**
     * Helper: Generate sparkline from values
     * @param {number[]} values - Array of values
     * @returns {string} Unicode sparkline
     */
    sparkline: function(values) {
        if (!values || values.length === 0) return '';
        const blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];
        const minVal = Math.min(...values);
        const maxVal = Math.max(...values);
        const range = maxVal - minVal || 1;
        return values.map(val => {
            const normalized = (val - minVal) / range;
            const index = Math.floor(normalized * (blocks.length - 1));
            return blocks[index];
        }).join('');
    }
};

// Shorthand for registering widgets
function LumenmonWidget(config) {
    window.LumenmonWidgets.register(config);
}
