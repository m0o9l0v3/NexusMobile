declare global {
  interface Window {
    __attachMapInteractions?: (
      viewport: HTMLElement,
      content: SVGGElement
    ) => void;
  }
}
