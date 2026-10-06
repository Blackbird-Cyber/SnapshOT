/*
 * SnapshOT Wiki graphs: mounts vis-network on every
 *   <div class="snapshot-graph" data-graph="NAME" data-height="520">
 * using the data in window.SNAPSHOT_GRAPHS[NAME] (assets/graphs/NAME.js,
 * written by hooks/snapshot_wiki.py). The hook adds this script, vis-network
 * and the graph data only to pages that contain a graph.
 *
 * Each graph gets zoom in, zoom out and full-screen buttons (top right);
 * the mouse wheel zooms only in full screen so it never hijacks page
 * scrolling.
 *
 * Works from file:// at any directory depth: node URLs in the data are
 * site-relative and are resolved against the site root, which is derived from
 * this script's own URL (it lives at <root>/assets/js/snapshot-graphs.js), or
 * failing that from Material's bundle script (<root>/assets/javascripts/...).
 */
(function () {
  "use strict";

  var INK = "#0A0B0C";
  var SURFACE = "#23252e";
  var LIGHT = "#F4F5F6";
  var MUTED = "#8A8D91";
  var RED = "#F1000E";
  var DIM_NODE = "#1b1d24";
  var DIM_TEXT = "#3a3d46";
  var DIM_EDGE = "rgba(138, 141, 145, 0.12)";
  var FONT = "Cantarell, 'Noto Sans', 'DejaVu Sans', sans-serif";

  var current = document.currentScript;

  function siteRoot() {
    var src = current && current.src;
    var mark = "assets/js/snapshot-graphs.js";
    if (src && src.indexOf(mark) !== -1) {
      return src.slice(0, src.lastIndexOf(mark));
    }
    var scripts = document.getElementsByTagName("script");
    for (var i = 0; i < scripts.length; i++) {
      var s = scripts[i].src || "";
      var at = s.indexOf("assets/javascripts/");
      if (at !== -1) return s.slice(0, at);
    }
    return new URL(".", document.baseURI).href;
  }

  function resolve(url) {
    return new URL(url, siteRoot()).href;
  }

  // vis-network colour object for a group: dots are filled, boxes are dark
  // cards with a coloured border so their labels stay readable.
  function nodeStyle(group, big) {
    var c = group.color || MUTED;
    var shape = group.shape || "dot";
    var boxy = shape === "box" || shape === "ellipse" || shape === "database" || shape === "circle";
    var style = {
      shape: shape,
      color: boxy
        ? { background: SURFACE, border: c, highlight: { background: SURFACE, border: LIGHT },
            hover: { background: SURFACE, border: LIGHT } }
        : { background: c, border: c, highlight: { background: c, border: LIGHT },
            hover: { background: c, border: LIGHT } },
      font: { face: FONT, color: LIGHT, size: big ? 17 : 13, strokeWidth: boxy ? 0 : 3, strokeColor: INK },
      borderWidth: boxy ? 1.5 : 1,
      size: big ? 13 : 11,
      shapeProperties: { borderRadius: 4 }
    };
    if (boxy) style.margin = { top: 8, right: 10, bottom: 8, left: 10 };
    return style;
  }

  function options(data) {
    // Large force graphs (the lifecycle and ATT&CK graphs carry every tool)
    // get larger labels and more room between nodes: fitting sixty nodes into
    // the content column zooms out far enough to make 13px labels unreadable.
    var big = !!(data.nodes && data.nodes.length > 40);
    var groups = {};
    Object.keys(data.groups || {}).forEach(function (name) {
      groups[name] = nodeStyle(data.groups[name], big);
    });
    var hierarchical = data.layout === "hierarchical";
    var opts = {
      autoResize: true,
      groups: groups,
      nodes: nodeStyle({ color: MUTED }),
      edges: {
        color: { color: MUTED, highlight: RED, hover: LIGHT, opacity: 0.55, inherit: false },
        width: 1,
        selectionWidth: 1.5,
        hoverWidth: 0.5,
        font: { face: FONT, color: MUTED, size: 11, strokeWidth: 3, strokeColor: INK,
                align: "horizontal" },
        smooth: hierarchical ? { type: "cubicBezier", forceDirection: data.direction === "LR" || data.direction === "RL" ? "horizontal" : "vertical", roundness: 0.4 } : { type: "continuous" },
        arrows: { to: { enabled: false, scaleFactor: 0.6 } }
      },
      interaction: { hover: true, tooltipDelay: 120, zoomView: false, dragView: true,
                     navigationButtons: false, keyboard: false, multiselect: false },
      physics: hierarchical ? { enabled: false } : {
        solver: "forceAtlas2Based",
        forceAtlas2Based: { gravitationalConstant: big ? -70 : -45, centralGravity: 0.008,
                            springLength: big ? 110 : 90, springConstant: 0.05,
                            avoidOverlap: big ? 0.8 : 0.4 },
        stabilization: { iterations: 400, fit: true },
        minVelocity: 0.75
      }
    };
    if (hierarchical) {
      // Levels are rows top-down and columns left-right; space them so the
      // graph keeps a readable aspect ratio either way.
      var horizontal = data.direction === "LR" || data.direction === "RL";
      opts.layout = {
        hierarchical: { enabled: true, direction: data.direction || "UD",
                        sortMethod: "directed",
                        levelSeparation: horizontal ? 260 : 120,
                        nodeSpacing: horizontal ? 45 : 170,
                        treeSpacing: horizontal ? 45 : 200,
                        blockShifting: true, edgeMinimization: true,
                        parentCentralization: true }
      };
    }
    return opts;
  }

  function edgeData(e, i) {
    var out = { id: "e" + i, from: e.from, to: e.to };
    if (e.label) out.label = e.label;
    if (e.title) out.title = e.title;
    if (e.dashes) out.dashes = [6, 6];
    if (e.arrows) out.arrows = e.arrows;
    if (e.color) out.color = { color: e.color, highlight: e.color, hover: e.color, opacity: 0.85 };
    return out;
  }

  function legend(container, data) {
    var names = Object.keys(data.groups || {}).filter(function (n) { return data.groups[n].label; });
    if (!names.length) return;
    var ul = document.createElement("ul");
    ul.className = "snapshot-graph__legend";
    names.forEach(function (name) {
      var g = data.groups[name];
      var li = document.createElement("li");
      var sw = document.createElement("span");
      sw.className = "snapshot-graph__swatch" + (g.shape === "box" ? " snapshot-graph__swatch--box" : "");
      sw.style.setProperty("--swatch", g.color);
      li.appendChild(sw);
      li.appendChild(document.createTextNode(g.label));
      ul.appendChild(li);
    });
    container.parentNode.insertBefore(ul, container.nextSibling);
  }

  // Hovering a node dims everything that is not connected to it. Nodes carry no
  // per-node colour (groups style them), so null restores the group style;
  // edges get back the colour their data gave them.
  function hoverHighlight(network, nodes, edges, original) {
    var dimmed = false;
    network.on("hoverNode", function (p) {
      var keep = {};
      keep[p.node] = true;
      network.getConnectedNodes(p.node).forEach(function (id) { keep[id] = true; });
      var keepEdges = {};
      network.getConnectedEdges(p.node).forEach(function (id) { keepEdges[id] = true; });
      nodes.update(nodes.getIds().filter(function (id) { return !keep[id]; }).map(function (id) {
        return { id: id, color: { background: DIM_NODE, border: DIM_NODE },
                 font: { color: DIM_TEXT, strokeWidth: 0 } };
      }));
      edges.update(edges.getIds().map(function (id) {
        return keepEdges[id]
          ? { id: id, color: { color: RED, highlight: RED, hover: RED, opacity: 1 }, width: 1.6 }
          : { id: id, color: { color: DIM_EDGE, opacity: 1 }, font: { color: "rgba(0,0,0,0)", strokeWidth: 0 } };
      }));
      dimmed = true;
    });
    network.on("blurNode", function () {
      if (!dimmed) return;
      nodes.update(nodes.getIds().map(function (id) { return { id: id, color: null, font: null }; }));
      edges.update(edges.getIds().map(function (id) {
        return { id: id, color: original[id] || null, width: null, font: null };
      }));
      dimmed = false;
    });
  }

  // Zoom and full-screen controls at the top right of the graph. The mouse
  // wheel scrolls the page, not the graph; it zooms only while the graph is
  // full screen. Native full screen is used where the browser allows it, with
  // a fixed-position fallback (and Escape to leave it) where it does not.
  var ICONS = {
    "in": '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M8 3v10M3 8h10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
    out: '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M3 8h10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
    full: '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    exit: '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M6 2v4H2M10 6V2h4M14 10h-4v4M2 10h4v4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>'
  };

  function controls(el, network) {
    var bar = document.createElement("div");
    bar.className = "snapshot-graph__controls";
    bar.setAttribute("role", "group");
    bar.setAttribute("aria-label", "Graph controls");
    function button(action, label) {
      var b = document.createElement("button");
      b.type = "button";
      b.className = "snapshot-graph__btn snapshot-graph__btn--" + action;
      b.title = label;
      b.setAttribute("aria-label", label);
      b.innerHTML = ICONS[action];
      bar.appendChild(b);
      return b;
    }
    var zoomIn = button("in", "Zoom in");
    var zoomOut = button("out", "Zoom out");
    var full = button("full", "Full screen");
    el.appendChild(bar);

    function zoom(factor) {
      network.moveTo({ scale: network.getScale() * factor, position: network.getViewPosition(),
                       animation: { duration: 150, easingFunction: "easeInOutQuad" } });
    }
    zoomIn.addEventListener("click", function () { zoom(1.3); });
    zoomOut.addEventListener("click", function () { zoom(1 / 1.3); });

    var savedHeight = el.style.height;
    var isFull = false;
    function applyFull(on) {
      isFull = on;
      el.classList.toggle("snapshot-graph--fullscreen", on);
      el.style.height = on ? "" : savedHeight;
      full.title = on ? "Exit full screen" : "Full screen";
      full.setAttribute("aria-label", full.title);
      full.innerHTML = on ? ICONS.exit : ICONS.full;
      network.setOptions({ interaction: { zoomView: on } });
      // The canvas follows the container size on vis-network's own timer;
      // redraw and fit as it catches up.
      [60, 400, 1100].forEach(function (ms) {
        window.setTimeout(function () { network.redraw(); network.fit({ animation: false }); }, ms);
      });
    }
    full.addEventListener("click", function () {
      if (isFull) {
        if (document.fullscreenElement === el && document.exitFullscreen) document.exitFullscreen();
        else applyFull(false);
        return;
      }
      if (!el.requestFullscreen) { applyFull(true); return; }
      // Native full screen where the browser grants it. Where it refuses, or an
      // embedded browser never answers, the fixed overlay takes over instead.
      var request = el.requestFullscreen();
      if (request && request.then) {
        request.then(null, function () { if (!isFull) applyFull(true); });
      }
      window.setTimeout(function () {
        if (!isFull && document.fullscreenElement !== el) applyFull(true);
      }, 500);
    });
    document.addEventListener("fullscreenchange", function () {
      var now = document.fullscreenElement === el;
      if (now !== isFull) applyFull(now);
    });
    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape" && isFull && !document.fullscreenElement) applyFull(false);
    });
  }

  function mount(el) {
    var name = el.getAttribute("data-graph");
    var data = (window.SNAPSHOT_GRAPHS || {})[name];
    if (!data || !window.vis || !window.vis.Network) return;
    var height = parseInt(el.getAttribute("data-height") || "480", 10);
    el.style.height = height + "px";
    el.innerHTML = "";
    el.setAttribute("role", "figure");
    el.setAttribute("aria-label", data.title || name);

    var nodes = new window.vis.DataSet(data.nodes.map(function (n) {
      var out = { id: n.id, label: n.label, group: n.group };
      if (n.title) out.title = n.title;
      if (n.level !== undefined) out.level = n.level;
      if (n.shape) out.shape = n.shape;
      if (n.url) out.url = n.url;
      return out;
    }));
    var edgeList = data.edges.map(edgeData);
    var original = {};
    edgeList.forEach(function (e) { if (e.color) original[e.id] = e.color; });
    var edges = new window.vis.DataSet(edgeList);
    var network = new window.vis.Network(el, { nodes: nodes, edges: edges }, options(data));

    network.once("stabilizationIterationsDone", function () {
      network.setOptions({ physics: { enabled: false } });
      network.fit({ animation: false });
    });
    hoverHighlight(network, nodes, edges, original);
    network.on("hoverNode", function (p) {
      el.style.cursor = nodes.get(p.node).url ? "pointer" : "default";
    });
    network.on("blurNode", function () { el.style.cursor = "default"; });
    network.on("click", function (p) {
      if (!p.nodes.length) return;
      var node = nodes.get(p.nodes[0]);
      if (node && node.url) window.location.href = resolve(node.url);
    });
    legend(el, data);
    controls(el, network);
    el.classList.add("snapshot-graph--ready");
  }

  function mountAll() {
    var els = document.querySelectorAll(".snapshot-graph[data-graph]");
    for (var i = 0; i < els.length; i++) {
      if (!els[i].classList.contains("snapshot-graph--ready")) mount(els[i]);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mountAll);
  } else {
    mountAll();
  }
}());
