/* Sourcing Documentation Sidebar */
(function() {
    var path = window.location.pathname;
    var prefix = './';
    
    // Determine depth based on path
    if (path.includes('/guides/')) {
        prefix = '../';
    } else if (path.includes('/api/') || path.includes('/concepts/')) {
        prefix = '../';
    }
    
    var guidePrefix = prefix + 'guides/';
    var apiPrefix = prefix + 'api/';
    var conceptPrefix = prefix + 'concepts/';

    var sidebarHTML = '<button class="menu-toggle" onclick="document.getElementById(\'sidebar\').classList.toggle(\'open\')">☰</button>' +
'<nav id="sidebar">' +
'    <div class="header">' +
'        <h1><a href="' + prefix + 'index.html">Sourcing</a></h1>' +
'        <p>Event Sourcing for Raku</p>' +
'        <p><a href="https://github.com/FCO/Sourcing-2">GitHub</a></p>' +
'    </div>' +
'    <div class="group">' +
'        <div class="group-title">Getting Started</div>' +
'        <a href="' + prefix + 'index.html">Home</a>' +
'        <a href="' + conceptPrefix + 'event-sourcing.html">What is Event Sourcing?</a>' +
'        <a href="' + conceptPrefix + 'cqrs.html">CQRS Pattern</a>' +
'        <a href="' + conceptPrefix + 'architecture.html">Architecture</a>' +
'    </div>' +
'    <div class="group">' +
'        <div class="group-title">Core Concepts</div>' +
'        <a href="' + conceptPrefix + 'projections.html">Projections</a>' +
'        <a href="' + conceptPrefix + 'aggregations.html">Aggregations</a>' +
'        <a href="' + conceptPrefix + 'saga.html">Sagas</a>' +
'        <a href="' + conceptPrefix + 'commands.html">Commands</a>' +
'        <a href="' + conceptPrefix + 'optimistic-locking.html">Optimistic Locking</a>' +
'        <a href="' + conceptPrefix + 'events.html">Events</a>' +
'    </div>' +
'    <div class="group">' +
'        <div class="group-title">API Reference</div>' +
'        <a href="' + apiPrefix + 'sourcing.html">sourcing()</a>' +
'        <a href="' + apiPrefix + 'projection.html">Sourcing::Projection</a>' +
'        <a href="' + apiPrefix + 'aggregation.html">Sourcing::Aggregation</a>' +
'        <a href="' + apiPrefix + 'saga.html">Sourcing::Saga</a>' +
'        <a href="' + apiPrefix + 'plugin.html">Sourcing::Plugin</a>' +
'        <a href="' + apiPrefix + 'event-store.html">EventStore Interface</a>' +
'        <a href="' + apiPrefix + 'state-cache.html">StateCache Interface</a>' +
'        <a href="' + apiPrefix + 'event-store-memory.html">EventStore::Memory</a>' +
'        <a href="' + apiPrefix + 'state-cache-memory.html">StateCache::Memory</a>' +
'        <a href="' + apiPrefix + 'event-store-sqlite.html">EventStore::SQLite</a>' +
'        <a href="' + apiPrefix + 'state-cache-sqlite.html">StateCache::SQLite</a>' +
'        <a href="' + apiPrefix + 'memory.html">Plugin::Memory (Combined)</a>' +
'        <a href="' + apiPrefix + 'projection-storage.html">ProjectionStorage</a>' +
'        <a href="' + apiPrefix + 'metaclasses.html">Metaclasses</a>' +
'        <a href="' + apiPrefix + 'traits.html">Traits</a>' +
'        <a href="' + apiPrefix + 'exceptions.html">Exceptions</a>' +
'    </div>' +
'    <div class="group">' +
'        <div class="group-title">Guides</div>' +
'        <a href="' + guidePrefix + 'quick-start.html">Quick Start</a>' +
'        <a href="' + guidePrefix + 'bank-account.html">Bank Account Example</a>' +
'        <a href="' + guidePrefix + 'shopping-cart.html">Shopping Cart Example</a>' +
'        <a href="' + guidePrefix + 'projections.html">Building Projections</a>' +
'        <a href="' + guidePrefix + 'plugins.html">Writing a Plugin</a>' +
'        <a href="' + guidePrefix + 'irc-bot.html">IRC Bot Example</a>' +
'    </div>' +
'</nav>';

    document.body.insertAdjacentHTML('afterbegin', sidebarHTML);

    var links = document.querySelectorAll('#sidebar a');
    links.forEach(function(link) {
        var href = link.getAttribute('href');
        if (path.endsWith(href) || (href === 'index.html' && (path.endsWith('/') || path === ''))) {
            link.classList.add('active');
        }
    });
})();
