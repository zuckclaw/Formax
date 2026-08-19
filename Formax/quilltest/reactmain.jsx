import React, { useState, useRef } from 'react'
import { createRoot } from 'react-dom/client'
import ReactQuill, { Quill } from 'react-quill-new'
import katex from 'katex'
import ImageResize from '@mgreminger/quill-image-resize-module'

window.katex = katex

const Font = Quill.import('formats/font')
Font.whitelist = ['sans-serif', 'serif', 'monospace', 'arial', 'georgia', 'courier-new', 'verdana', 'trebuchet', 'times-new-roman']
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
  imageResize: {},
}

const formats = [
  'header', 'bold', 'italic', 'underline', 'strike', 'color', 'background',
  'font', 'size', 'align', 'list', 'indent', 'blockquote', 'code-block',
  'link', 'image', 'formula',
]

const out = []
const results = () => {
  document.getElementById('result').textContent = out.join('\n')
  console.log('TESTRESULT_BEGIN\n' + out.join('\n') + '\nTESTRESULT_END')
}

function App() {
  const [desc, setDesc] = useState('Evaluasi materi pertemuan 1-7 mata pelajaran Geografi.')
  const [title, setTitle] = useState('Ibu kota Indonesia adalah?')
  const descRef = useRef(null)
  const titleRef = useRef(null)

  const runTests = async () => {
    const q1 = descRef.current.getEditor()
    const q2 = titleRef.current.getEditor()
    const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

    // code-block on title FIRST, in isolation
    q2.setText('function foo(){}')
    q2.setSelection(0, 15)
    await sleep(50)
    document.querySelectorAll('.ql-code-block')[1].click()
    await sleep(50)
    out.push('T1 title-codeblock(alone): ' + JSON.stringify(q2.getContents()))
    results()

    // italic then codeblock in sequence with delays
    q2.setText('hello title world')
    q2.setSelection(0, 5)
    await sleep(50)
    document.querySelectorAll('.ql-italic')[1].click()
    await sleep(50)
    out.push('T2 title-italic: ' + JSON.stringify(q2.getContents().ops[0].attributes || {}))
    results()

    q2.setText('const a = 5')
    q2.setSelection(0, 11)
    await sleep(50)
    document.querySelectorAll('.ql-code-block')[1].click()
    await sleep(50)
    out.push('T3 title-codeblock(after italic): ' + JSON.stringify(q2.getContents()))
    results()

    // desc editor codeblock alone
    q1.setText('var b = 10')
    q1.setSelection(0, 10)
    await sleep(50)
    document.querySelectorAll('.ql-code-block')[0].click()
    await sleep(50)
    out.push('T4 desc-codeblock(alone): ' + JSON.stringify(q1.getContents()))
    results()

    // italic alone on desc
    q1.setText('hello desc world')
    q1.setSelection(0, 5)
    await sleep(50)
    document.querySelectorAll('.ql-italic')[0].click()
    await sleep(50)
    out.push('T5 desc-italic(alone): ' + JSON.stringify(q1.getContents().ops[0].attributes || {}))
    results()

    // Bold for comparison
    q2.setText('bold test words')
    q2.setSelection(0, 4)
    await sleep(50)
    document.querySelectorAll('.ql-bold')[1].click()
    await sleep(50)
    out.push('T6 title-bold: ' + JSON.stringify(q2.getContents().ops[0].attributes || {}))
    results()
  }

  return (
    <div>
      <button id="run" onClick={runTests}>Run</button>
      <div id="editor1">
        <ReactQuill ref={descRef} theme="snow" value={desc} onChange={setDesc} modules={modules} formats={formats} placeholder="Deskripsi Form" />
      </div>
      <div id="editor2">
        <ReactQuill ref={titleRef} theme="snow" value={title} onChange={setTitle} modules={modules} formats={formats} placeholder="Pertanyaan" />
      </div>
    </div>
  )
}

createRoot(document.getElementById('root')).render(<App />)
setTimeout(() => document.getElementById('run').click(), 600)