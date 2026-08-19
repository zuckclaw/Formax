import ReactQuill, { Quill } from 'react-quill-new'
import 'react-quill-new/dist/quill.snow.css'
import katex from 'katex'
import 'katex/dist/katex.min.css'
import hljs from 'highlight.js'
import 'highlight.js/styles/atom-one-dark.min.css'
import ImageResize from '@mgreminger/quill-image-resize-module'

if (typeof window !== 'undefined') {
  window.katex = katex
  window.hljs = hljs
}

const Font = Quill.import('formats/font')
Font.whitelist = [
  'sans-serif',
  'serif',
  'monospace',
  'arial',
  'georgia',
  'courier-new',
  'verdana',
  'trebuchet',
  'times-new-roman',
]
Quill.register(Font, true)

Quill.register('modules/imageResize', ImageResize)

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
  syntax: {
    hljs,
  },
  imageResize: {
    modules: ['Resize', 'DisplaySize', 'AltText'],
    minWidth: 20,
    keyboardSizeDelta: 10,
    altTextPlaceholder: 'Deskripsi gambar...',
    altTextLabel: 'Teks Alt:',
    overlayStyles: {
      position: 'absolute',
      boxSizing: 'border-box',
      border: '1px dashed #2563eb',
    },
    handleStyles: {
      position: 'absolute',
      height: '12px',
      width: '12px',
      backgroundColor: '#ffffff',
      border: '2px solid #2563eb',
      boxSizing: 'border-box',
      borderRadius: '3px',
    },
    displayStyles: {
      position: 'absolute',
      font: '12px/1.2 "Inter", Arial, Helvetica, sans-serif',
      padding: '4px 8px',
      textAlign: 'center',
      backgroundColor: '#2563eb',
      color: '#ffffff',
      border: 'none',
      borderRadius: '4px',
      cursor: 'default',
    },
  },
}

const RichTextEditor = ({ value, onChange, placeholder, className }) => {
  return (
    <ReactQuill
      theme="snow"
      value={value}
      onChange={onChange}
      placeholder={placeholder}
      modules={modules}
      className={className}
    />
  )
}

export default RichTextEditor