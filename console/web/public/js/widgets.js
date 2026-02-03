/**
 * Lumenmon Widget System
 * Modular widgets that mirror agent collector structure.
 * Each widget declares its metrics, type, and render function.
 */

window.LumenmonWidgets = {
    registered: {},
    instances: {},

    // Grid size mapping: size -> CSS class (4-column grid)
    // xs=1/4, sm=2/4, md=3/4, lg=4/4 (full)
    gridSizes: {
        'sparkline': 'grid-xs',   // 1/4 width (1 column)
        'stat': 'grid-sm',        // 2/4 width (2 columns)
        'chart': 'grid-sm',       // 2/4 width (2 columns)
        'table': 'grid-lg'        // Full width (4 columns)
    },

    /**
     * Register a widget
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
            priority: config.priority || 50,
            interval: config.interval || 1000,
            render: config.render || function() {},
            init: config.init || null,
            update: config.update || null
        };
    },

    /**
     * Match metric name against widget patterns
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
     */
    findMatching: function(metricNames) {
        const matched = [];

        for (const [name, widget] of Object.entries(this.registered)) {
            if (widget.metrics.length === 0) {
                matched.push({ widget: widget, metrics: [] });
                continue;
            }

            const matchingMetrics = metricNames.filter(m =>
                this.matchesPattern(m, widget.metrics)
            );

            if (matchingMetrics.length > 0) {
                matched.push({ widget: widget, metrics: matchingMetrics });
            }
        }

        return matched;
    },

    /**
     * Render all matching widgets for an agent
     */
    renderAll: function(container, agent, tables) {
        const metricNames = tables.map(t => t.metric_name);
        const matched = this.findMatching(metricNames);

        this.instances = {};

        // Sort by priority (lower = first), then by size
        const sizeOrder = { 'sparkline': 0, 'stat': 1, 'chart': 2, 'table': 3 };
        matched.sort((a, b) => {
            if (a.widget.priority !== b.widget.priority) {
                return a.widget.priority - b.widget.priority;
            }
            return (sizeOrder[a.widget.size] || 99) - (sizeOrder[b.widget.size] || 99);
        });

        // Build grid
        let html = '<div class="widget-grid">';
        let widgetIndex = 0;

        matched.forEach(m => {
            const widgetData = this.getWidgetData(m.metrics, tables);
            const gridClass = m.widget.gridSize
                ? `grid-${m.widget.gridSize}`
                : (this.gridSizes[m.widget.size] || 'grid-sm');

            html += `<div class="widget widget-${m.widget.size} ${gridClass}" data-widget="${m.widget.name}" data-index="${widgetIndex}">`;
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

        // Initialize widgets that need it (e.g., charts)
        matched.forEach(m => {
            if (m.widget.init) {
                const widgetData = this.getWidgetData(m.metrics, tables);
                const el = container.querySelector(`[data-widget="${m.widget.name}"]`);
                if (el) m.widget.init(el, widgetData, agent);
            }
        });
    },

    /**
     * Update all widgets with new data
     */
    updateAll: function(container, agent, tables) {
        for (const [name, instance] of Object.entries(this.instances)) {
            const el = container.querySelector(`[data-widget="${name}"]`);
            if (!el) continue;

            instance.agent = agent;
            const widgetData = this.getWidgetData(instance.metrics, tables);
            instance.data = widgetData;

            if (instance.widget.update) {
                instance.widget.update(el, widgetData, agent);
            } else if (instance.widget.init) {
                // Chart widgets: re-render and re-init
                el.innerHTML = instance.widget.render(widgetData, agent);
                instance.widget.init(el, widgetData, agent);
            } else {
                el.innerHTML = instance.widget.render(widgetData, agent);
            }
        }
    },

    /**
     * Get data for widget from tables
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
