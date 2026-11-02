// Style overrides for the valt paper key document. valt keys/paper --css FILE uses FILE instead of this one.
//
// The template applies the style function below after its own rules, so set and show rules here take precedence. For
// example, to use a different body font and heading color:
//
//   #let style(doc) = {
//     set text(font: "Libertinus Serif")
//     show heading: set text(fill: rgb("#7852ee"))
//     doc
//   }
//
// Fonts can be any installed font (static or variable), or one in valt's etc/fonts directory.

#let style(doc) = doc
