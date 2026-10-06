/*
 * SnapshOT Wiki graphs: mounts vis-network on every
 *   <div class="snapshot-graph" data-graph="NAME" data-height="520">
 * using the data in window.SNAPSHOT_GRAPHS[NAME] (assets/graphs/NAME.js,
 * written by hooks/snapshot_wiki.py). The hook adds this script, vis-network
 * and the graph data only to pages that contain a graph.
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
  function nodeStyle(group) {
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
      font: { face: FONT, color: LIGHT, size: 13, strokeWidth: boxy ? 0 : 3, strokeColor: INK },
      borderWidth: boxy ? 1.5 : 1,
      size: 11,
      shapeProperties: { borderRadius: 4 }
    };
    if (boxy) style.margin = { top: 8, right: 10, bottom: 8, left: 10 };
    return style;
  }

  function options(data) {
    var groups = {};
    Object.keys(data.groups || {}).forEach(function (name) {
      groups[name] = nodeStyle(data.groups[name]);
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
      interaction: { hover: true, tooltipDelay: 120, zoomView: true, dragView: true,
                     navigationButtons: false, keyboard: false, multiselect: false },
      physics: hierarchical ? { enabled: false } : {
        solver: "forceAtlas2Based",
        forceAtlas2Based: { gravitationalConstant: -45, centralGravity: 0.008,
                            springLength: 90, springConstant: 0.05, avoidOverlap: 0.4 },
        stabilization: { iterations: 400, fit: true },
        minVelocity: 0.75
      }
    };
    if (hierarchical) {
      opts.layout = {
        hierarchical: { enabled: true, direction: data.direction || "UD",
                        sortMethod: "directed", levelSeparation: 120, nodeSpacing: 170,
                        treeSpacing: 200, parentCentralization: true }
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

  function mount(el) {
    var name = el.getAttribute("data-graph");
    var data = (window.SNAPSHOT_GRAPHS || {})[name];
    if (!data || !window.vis || !window.vis.Network) return;
    var height = parseInt(el.getAttribute("data-height") || "480", 10);
    el.style.height = height + "px";
    el.innerHTML = "";
    el.setAttribute("role", "img");
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
