{# Copy of RenderCV's built-in typst/Header.j2.typ (RenderCV 2.8), changed only where marked below.
   RenderCV uses it instead of the built-in one because it's in a folder named after the theme, next to the CV
   YAML files. Keep it in sync with the built-in template when RenderCV is updated. #}
{% macro image() %}
#pad(left: {{ design.header.photo_space_left }}, right: {{ design.header.photo_space_right }}, image("{{ cv.photo.name }}", width: {{ design.header.photo_width }}))
{% endmacro %}

{% if cv.photo %}
{% set photo = "image(\"" + cv.photo|string + "\", width: "+ design.header.photo_width + ")" %}
#grid(
{% if design.header.photo_position == "left" %}
  columns: (auto, 1fr),
{% else %}
  columns: (1fr, auto),
{% endif %}
  column-gutter: 0cm,
  align: horizon + left,
{% if design.header.photo_position == "left" %}
  [{{ image() }}],
  [
{% else %}
  [
{% endif %}
{% endif %}
{% if cv.name %}
= {{ cv.name }}
{% endif %}

{% if cv.headline %}
  #headline([{{ cv.headline }}])

{% endif %}
{# Contact details on two lines: location and email, then the rest. ATS parsers that read the PDF line by
   line otherwise merge the phone number with the email and can't find it. #}
#connections(
{% for connection in cv._connections[:2] %}
  [{{ connection }}],
{% endfor %}
)
#connections(
{% for connection in cv._connections[2:] %}
  [{{ connection }}],
{% endfor %}
)
{% if cv.photo %}
{% if design.header.photo_position == "left" %}
  ]
)
{% else %}
  ],
  [{{ image() }}],
)
{% endif %}
{% endif %}
