import { useState } from 'react'
import Autocomplete from '@mui/material/Autocomplete'
import TextField from '@mui/material/TextField'
import axios from 'axios'
import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
import './App.css'

const wikiHost = "en.wikipedia.org"

function App() {
  const [count, setCount] = useState(0)

  const [categories, setCategories] = useState<[{label}]>([])


  const inputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const target = (event.target || event.currentTarget) as HTMLInputElement
    console.log(target.value)

    axios.get(
      "https://" + wikiHost + "/w/api.php?action=query&list=allcategories&acprefix=" + target.value + "&origin=*&format=json",
    ).then((result) => {
      const matched = result.data.query.allcategories.map((item) => item["*"])
      const formated = matched.map((item) => { return { label: item } })
      setCategories(formated)
    })

  }

  return (
    <>
      <Autocomplete
        disablePortal
        id="combo-box-demo"
        onInputChange={inputChange}
        options={categories}
        sx={{ width: 300 }}
        renderInput={(params) => <TextField {...params} label="Category" />}
      />
      <div>
        <a href="https://vitejs.dev" target="_blank">
          <img src={viteLogo} className="logo" alt="Vite logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
      </div>
      <h1>Vite + React</h1>
      <div className="card">
        <button onClick={() => setCount((count) => count + 1)}>
          count is {count}
        </button>
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite and React logos to learn more
      </p>
    </>
  )
}

export default App
