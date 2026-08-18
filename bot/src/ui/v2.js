"use strict";

const {
  ContainerBuilder,
  SectionBuilder,
  TextDisplayBuilder,
  SeparatorBuilder,
  ButtonBuilder,
  ActionRowBuilder,
} = require("discord.js");

/** @typedef {import("discord.js").APIContainerComponent} APIContainerComponent */
/** @typedef {import("discord.js").APITextDisplay} APITextDisplay */
/** @typedef {import("discord.js").APISection} APISection */
/** @typedef {import("discord.js").APISeparator} APISeparator */
/** @typedef {import("discord.js").ButtonStyle} ButtonStyle */

/**
 * Separator spacing sizes enum values
 * @type {object}
 */
const SeparatorSpacing = {
  None: 0,
  Small: 4,
  Medium: 8,
  Large: 16,
};

/**
 * Build a header TextDisplay with icon and title.
 * @param {string} icon
 * @param {string} title
 * @returns {TextDisplayBuilder}
 */
function header(icon, title) {
  return new TextDisplayBuilder().setContent(`# ${icon} ${title}`);
}

/**
 * Build a body TextDisplay with markdown content.
 * @param {string} content
 * @returns {TextDisplayBuilder}
 */
function body(content) {
  return new TextDisplayBuilder().setContent(content);
}

/**
 * Build a separator.
 * @param {boolean} [divider=true]
 * @param {keyof SeparatorSpacing} [spacing="Small"]
 * @returns {SeparatorBuilder}
 */
function separator(divider = true, spacing = "Small") {
  return new SeparatorBuilder()
    .setDivider(divider)
    .setSpacing(SeparatorSpacing[spacing] ?? SeparatorSpacing.Small);
}

/**
 * Build a Section with optional button accessory.
 * @param {TextDisplayBuilder[]} textDisplays
 * @param {ButtonBuilder} [button]
 * @returns {SectionBuilder}
 */
function section(textDisplays, button) {
  const builder = new SectionBuilder().setTextDisplays(textDisplays);
  if (button) {
    builder.setButtonAccessory(button);
  }
  return builder;
}

/**
 * Build a simple container with header and body.
 * @param {string} icon
 * @param {string} title
 * @param {string} [bodyContent]
 * @param {number} [accentColor]
 * @returns {ContainerBuilder}
 */
function simpleContainer(icon, title, bodyContent, accentColor) {
  const container = new ContainerBuilder();
  container.addTextDisplayComponents(header(icon, title));
  if (bodyContent) {
    container.addTextDisplayComponents(body(bodyContent));
  }
  if (accentColor !== undefined) {
    container.setAccentColor(accentColor);
  }
  return container;
}

/**
 * Build a container with sections separated by dividers.
 * @param {Array<{text: TextDisplayBuilder|SectionBuilder, spacing?: keyof SeparatorSpacing}>} sections
 * @param {number} [accentColor]
 * @returns {ContainerBuilder}
 */
function containerWithSections(sections, accentColor) {
  const container = new ContainerBuilder();

  for (let i = 0; i < sections.length; i++) {
    const s = sections[i];

    if (s.text instanceof SectionBuilder) {
      container.addSectionComponents(s.text);
    } else {
      container.addTextDisplayComponents(s.text);
    }

    if (i < sections.length - 1) {
      container.addSeparatorComponents(separator(true, s.spacing || "Small"));
    }
  }

  if (accentColor !== undefined) {
    container.setAccentColor(accentColor);
  }
  return container;
}

/**
 * Build a loading container with animated spinner.
 * @param {string} icon
 * @param {string} title
 * @param {number} [accentColor]
 * @returns {ContainerBuilder}
 */
function loadingContainer(icon, title, accentColor) {
  return simpleContainer(icon, title, "Processing…", accentColor);
}

/**
 * Build a success container.
 * @param {string} icon
 * @param {string} title
 * @param {string} bodyContent
 * @param {number} [accentColor]
 * @returns {ContainerBuilder}
 */
function successContainer(icon, title, bodyContent, accentColor) {
  return simpleContainer(icon, title, bodyContent, accentColor);
}

/**
 * Build an error container.
 * @param {string} icon
 * @param {string} title
 * @param {string} errorMessage
 * @returns {ContainerBuilder}
 */
function errorContainer(icon, title, errorMessage) {
  const container = new ContainerBuilder();
  container.addTextDisplayComponents(header(icon, title));
  container.addTextDisplayComponents(body(errorMessage));
  container.setAccentColor(0xef4444); // Red
  return container;
}

/**
 * Build a button.
 * @param {string} label
 * @param {string} customId
 * @param {ButtonStyle} [style]
 * @returns {ButtonBuilder}
 */
function button(label, customId, style = 2 /* Secondary */) {
  return new ButtonBuilder()
    .setLabel(label)
    .setCustomId(customId)
    .setStyle(style);
}

/**
 * Spinner animation frames (block glyphs).
 */
const SPINNER_FRAMES = ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "▊"];

let spinnerIndex = 0;

/**
 * Get next spinner frame.
 * @returns {string}
 */
function nextSpinner() {
  const frame = SPINNER_FRAMES[spinnerIndex % SPINNER_FRAMES.length];
  spinnerIndex++;
  return frame;
}

/**
 * Reset spinner to beginning.
 */
function resetSpinner() {
  spinnerIndex = 0;
}

module.exports = {
  SeparatorSpacing,
  header,
  body,
  separator,
  section,
  simpleContainer,
  containerWithSections,
  loadingContainer,
  successContainer,
  errorContainer,
  button,
  SPINNER_FRAMES,
  nextSpinner,
  resetSpinner,
};
