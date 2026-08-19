import Quill from 'quill'
import ImageResize from '@mgreminger/quill-image-resize-module'

const out = []

const Font = Quill.import('formats/font')
out.push('formats/font class: ' + (Font && Font.className))
Font.whitelist = ['sans-serif', 'serif', 'monospace', 'arial', 'georgia', 'courier-new', 'verdana', 'trebuchet', 'times-new-roman']
Quill.register(Font, true)
Quill.register('modules/imageResize', ImageResize)

const FontStyle = Quill.import('attributors/style/font')
out.push('attributors/style/font whitelist: ' + JSON.stringify(FontStyle.whitelist))

const modules = {
  toolbar: [
    [{ header: [1, 2, 3, false] }],
    ['bold', 'italic', 'underline', 'strike'],
    [{ color: [] }, { background: [] }],
    [{ font: [] }],
    [{ size: ['small', false, 'large', 'huge'] }],
    [{ align: [] }],
    [{ list: 'ordered' }, { list: 'bullet' }],
    [{ indent: '-1' }, { indent: '+1' }],
    ['blockquote', 'code-block'],
    ['link', 'image'],
    ['formula'],
    ['clean'],
  ],
  imageResize: {},
}

const formats = [
  'header', 'bold', 'italic', 'underline', 'strike', 'color', 'background',
  'font', 'size', 'align', 'list', 'indent', 'blockquote', 'code-block',
  'link', 'image', 'formula',
]

const quill = new Quill('#editor', {
  theme: 'snow',
  modules,
  formats,
  placeholder: 'Test',
})

// code-block via API - full delta
quill.setText('const x = 1')
quill.setSelection(0, 11)
quill.format('code-block', true)
out.push('codeblock-api full delta: ' + JSON.stringify(quill.getContents()))

// code-block via button - full delta
quill.setText('const x = 1')
quill.setSelection(0, 11)
document.querySelector('.ql-code-block').click()
out.push('codeblock-button full delta: ' + JSON.stringify(quill.getContents()))

// italic persists after setContents round-trip (simulating controlled value)
quill.setText('hello world')
quill.setSelection(0, 5)
quill.format('italic', true)
const delta = quill.getContents()
quill.setContents(delta)
out.push('italic-after-setContents: ' + JSON.stringify(quill.getContents().ops[0].attributes || {}))

// code block inside a list/paragraph context
quill.setContents([
  { insert: 'line one\n' },
  { insert: 'const a = 1' },
  { insert: '\n', attributes: { 'code-block': true } },
])
out.push('codeblock-setContents-delta: ' + JSON.stringify(quill.getContents()))

const fontOptions = Array.from(document.querySelectorAll('.ql-font .ql-picker-item')).map((el) => el.getAttribute('data-value'))
out.push('font-dropdown-options: ' + JSON.stringify(fontOptions))

document.getElementById('result').textContent = out.join('\n')
console.log('TESTRESULT_BEGIN\n' + out.join('\n') + '\nTESTRESULT_END')