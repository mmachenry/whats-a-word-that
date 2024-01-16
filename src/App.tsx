import { useState } from 'react'
import Autocomplete from '@mui/material/Autocomplete'
import TextField from '@mui/material/TextField'
import axios from 'axios'
import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
import './App.css'

const wikiHost = "en.wikipedia.org"

function App() {
  const [category, setCategory] = useState<string>("")
  const [categories, setCategories] = useState<string[]>([])
  const [members, setMembers] = useState<string[]>([])

  const blurit = () => {
    console.log("https://" + wikiHost + "/w/api.php?action=query&list=categorymembers&origin=*&format=json&cmtitle=" + category)
    axios.get("https://" + wikiHost + "/w/api.php?action=query&list=categorymembers&origin=*&format=json&cmtitle=Category:" + category
    ).then((result) => {
      console.log(result)
      setMembers(result.data.query.categorymembers.map((m) => m.title))
    })
  }

  const inputChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const target = (event.target || event.currentTarget) as HTMLInputElement
    setCategory(target.value)

    axios.get(
      "https://" + wikiHost + "/w/api.php?action=query&list=allcategories&acprefix=" + target.value + "&origin=*&format=json",
    ).then((result) => {
      const matched = result.data.query.allcategories.map(
        (item) => item["*"]
      )
      setCategories(matched)
    })
  }

  return (
    <>
      <Autocomplete
        disablePortal
        onInputChange={inputChange}
        onBlur={blurit}
        options={categories}
        sx={{ width: 300 }}
        renderInput={(params) => <TextField {...params} label="Category" />}
      />
      <ul>
        {members.map((title, idx) => ( <li>{title}</li>)) }
      </ul>
    </>
  )
}

export default App
